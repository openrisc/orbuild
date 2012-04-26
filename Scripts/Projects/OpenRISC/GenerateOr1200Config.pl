#!/usr/bin/perl

=head1 OVERVIEW

This tool generates a configuration file derived from or1200_defines.v

It loads a Verilog file with many configuration settings in the following form:

  `define ENABLE_FEATURE_AAA
  `define ENABLE_FEATURE_BBB
  // `define ENABLE_FEATURE_BBB

It then changes some of those settings, by commenting them out wherever they are defined in the file,
and then defining those constants (or not defining them) at the beginning of the file.
The rest of the Verilog file is left unmodified.

Warning: The Verilog parsing is very rudimentary, so no fancy files please. Multiline comments
         in the form /* */ are not supported and may lead to invalid output.

=head1 USAGE

perl GenerateOr1200Config.pl < source-file.v > < destination-file.v > < config name >

=head1 OPTIONS

-h, --help, --version, --license

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 FEEDBACK

Please send feedback to rdiezmail-openrisc at yahoo.de

=head1 LICENSE

Copyright (C) 2012 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings; 
use integer;  # There is no reason to resort to floating point in this script.

use Getopt::Long;
use FindBin;

use constant THIS_SCRIPT_DIR => $FindBin::Bin;

use lib THIS_SCRIPT_DIR . "/../../PerlModules";
use MiscUtils;
use FileUtils;
use AGPL3;

use constant SCRIPT_NAME => $0;

use constant APP_NAME    => "GenerateOr1200Config.pl";
use constant APP_VERSION => "0.10";  # If you update the version number, update also the perldoc text above if needed.


# ----------- main routine, the script entry point is at the bottom -----------

sub main ()
{
  my $arg_help             = 0;
  my $arg_h                = 0;
  my $arg_version          = 0;
  my $arg_license          = 0;

  my $result = GetOptions(
                 'help'                =>  \$arg_help,
                 'h'                   =>  \$arg_h,
                 'version'             =>  \$arg_version,
                 'license'             =>  \$arg_license
                );

  if ( not $result )
  {
    # GetOptions has already printed an error message.
    return MiscUtils::EXIT_CODE_FAILURE_ARGS;
  }

  if ( $arg_help || $arg_h )
  {
    write_stdout( "\n" . MiscUtils::get_cmdline_help_from_pod( SCRIPT_NAME ) );
    return MiscUtils::EXIT_CODE_SUCCESS;
  }

  if ( $arg_version )
  {
    write_stdout( "@{[APP_NAME]} version @{[APP_VERSION]}\n" );
    return MiscUtils::EXIT_CODE_SUCCESS;
  }

  if ( $arg_license )
  {
    write_stdout( AGPL3::get_agpl3_license_text() );
    return MiscUtils::EXIT_CODE_SUCCESS;
  }

  if ( scalar( @ARGV ) != 3 )
  {
    die "Invalid number of arguments. Run this program with the --help option for usage information.\n";
  }

  my $srcFile       = shift @ARGV;
  my $destFilename  = shift @ARGV;
  my $configName    = shift @ARGV;

  write_stdout( "Reading \"$srcFile\"...\n" );

  my @allLines = FileUtils::read_text_file( $srcFile );

  # write_stdout( "Line count: " . scalar( @allLines ) . "\n" );


  if ( scalar( @allLines ) < 2 )
  {
    die "This tool cannot operate on an empty or nearly empty Verilog file.\n";
  }

  my $eolChars = StringUtils::collect_eol_characters( $allLines[0] );


  # This EOL check on the last line simplifies the line-processing logic later on.

  my $lastLine = $allLines[ scalar( @allLines - 1 ) ];
  # write_stdout("Last line: <$lastLine>\n");

  if ( !StringUtils::str_ends_with( $lastLine, $eolChars )  )
  {
    die "Invalid last line in \"$srcFile\". Is the last line a blank line? The last line must end with the same end-of-line characters (Unix or Windows style) as the first one.\n";
  }


  write_stdout( "Adjusting configuration settings...\n" );

  my %allConfigSettings;

  populate_config_settings( $configName, \%allConfigSettings );


  my @newLinesAtTheTop;

  push @newLinesAtTheTop, "// This file has been generated by @{[APP_NAME]} version @{[APP_VERSION]}" . $eolChars . $eolChars;
  push @newLinesAtTheTop, "// Begin of the generated settings header." . $eolChars;

  foreach my $settingName ( keys %allConfigSettings )
  {
    my $settingValue = $allConfigSettings{ $settingName };
    adjust_setting( $settingName, $settingValue, APP_NAME, $eolChars, \@allLines );

    if ( $settingValue )
    {
      push @newLinesAtTheTop, "`define $settingName" . $eolChars;
    }
    else
    {
      push @newLinesAtTheTop, "// `define $settingName" . $eolChars;
    }
  }

  push @newLinesAtTheTop, "// End of the generated settings header." . $eolChars . $eolChars;

  my $all_in_a_single_string = join( "", ( @newLinesAtTheTop, @allLines ) );

  FileUtils::write_string_to_new_file( $destFilename, $all_in_a_single_string );

  write_stdout( "Configuration file finished.\n" );

  return MiscUtils::EXIT_CODE_SUCCESS;
}


sub add_config_setting ( $ $ $ )
{
  my $allConfigSettings = shift;  # Reference to a hash.
  my $settingName       = shift;
  my $settingValue      = shift;

  if ( exists $allConfigSettings->{ $settingName } )
  {
    die qq<Duplicate configuration setting "$settingName".\n>;
  }

  $allConfigSettings->{ $settingName } = $settingValue;
}


sub populate_config_settings ( $ $ )
{
  my $configName     = shift;
  my $allConfigSettings = shift;  # Reference to a hash.

  my $enable;

  if ( $configName eq "minimal-features" )
  {
    $enable = 0;
  }
  elsif ( $configName eq "maximal-features" or $configName eq "maximal-features-alt-cfg" )
  {
    $enable = 1;
  }
  else
  {
    die qq<Invalid configuration name "$configName".\n>;
  }

  add_config_setting( $allConfigSettings, "OR1200_NO_DC"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_NO_IC"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_NO_DMMU" , $enable );
  add_config_setting( $allConfigSettings, "OR1200_NO_IMMU" , $enable );

  add_config_setting( $allConfigSettings, "OR1200_IMPL_ADDC"  , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_SUB"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_CY"    , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_OV"    , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_OVE"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_ALU_ROTATE" , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_ALU_FFL1"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_IMPL_ALU_EXT"    , $enable );

  add_config_setting( $allConfigSettings, "OR1200_MULT_IMPLEMENTED" , $enable );
  add_config_setting( $allConfigSettings, "OR1200_MAC_IMPLEMENTED"  , $enable );
  add_config_setting( $allConfigSettings, "OR1200_DIV_IMPLEMENTED"  , $enable );
  add_config_setting( $allConfigSettings, "OR1200_FPU_IMPLEMENTED"  , $enable );
  add_config_setting( $allConfigSettings, "OR1200_PM_IMPLEMENTED"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_DU_IMPLEMENTED"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_DU_STATUS_UNIMPLEMENTED" , $enable );
  add_config_setting( $allConfigSettings, "OR1200_PIC_IMPLEMENTED"  , $enable );
  add_config_setting( $allConfigSettings, "OR1200_TT_IMPLEMENTED"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_SB_IMPLEMENTED"   , $enable );
  add_config_setting( $allConfigSettings, "OR1200_QMEM_IMPLEMENTED" , $enable );
  add_config_setting( $allConfigSettings, "OR1200_CFGR_IMPLEMENTED" , $enable );

  if ( $configName eq "maximal-features-alt-cfg" )
  {
    # alt-cfg means "alternative configuration", currently:
    # 1) No Wishbone B3.       TODO: disabled at the moment because it does not work.
    # 2) ASIC instead of FPGA. TODO: disabled at the moment because it does not work.
    add_config_setting( $allConfigSettings, "OR1200_ASIC" , 0 );
    add_config_setting( $allConfigSettings, "OR1200_WB_B3", 1 );
  }
  else
  {
    add_config_setting( $allConfigSettings, "OR1200_ASIC" , 0 );
    add_config_setting( $allConfigSettings, "OR1200_WB_B3", 1 );
  }
}


sub adjust_setting ( $ $ $ $ $ )
{
  my $settingName       = shift;
  my $settingValue      = shift;
  my $changingAgentName = shift;
  my $eolChars          = shift;
  my $allLines          = shift;  # Reference to an array.

  my @newLinesAtTheTop;

  # write_stdout( "Adjusting setting $settingName to $settingValue...\n" );

  # Copy all lines to a new array, modify the ones we are interested about.

  my @allLinesRes;

  foreach my $line ( @$allLines )
  {
    push @allLinesRes, adjust_setting_process_line ( $line,
                                                     $settingName,
                                                     $settingValue,
                                                     $changingAgentName );
  }

  @$allLines = @allLinesRes;
}


sub adjust_setting_process_line ( $ $ $ $ )
{
  my $line              = shift;
  my $settingName       = shift;
  my $settingValue      = shift;
  my $changingAgentName = shift;

  my @parts = $line =~ m/ ^ (\s*)            # Any blanks at the beginning.
                          (.*?)              # Anything in between, non-greedy.
                          `define
                          (\s*)              # Any blanks after the `define.
                          $settingName
                          (\s*)              # Any blanks afterwards. We require at least one blank character, although Verilog accepts other characters.
                          (.*)               # Anything else.
                          $                  # End of the string.
                        /sx ;

  if ( scalar( @parts ) != 5 )
  {
    return $line;
  }

  use constant LEFT_BLANKS  => 0;
  use constant PREFIX       => 1;
  use constant MID_BLANKS   => 2;
  use constant RIGHT_BLANKS => 3;
  use constant SUFFIX       => 4;

  if ( 0 )
  {
    write_stdout( "Found line with " . scalar( @parts ) . " components: <" . StringUtils::remove_trailing_eol( $line ) . ">\n" );
    write_stdout( "Left blanks : <" . $parts[ LEFT_BLANKS  ] . ">\n" );
    write_stdout( "Prefix      : <" . $parts[ PREFIX       ] . ">\n" );
    write_stdout( "Mid blanks  : <" . $parts[ MID_BLANKS   ] . ">\n" );
    write_stdout( "Right blanks: <" . StringUtils::remove_trailing_eol( $parts[ RIGHT_BLANKS ] ) . ">\n" );
    write_stdout( "Suffix      : <" . $parts[ SUFFIX       ] . ">\n" );
  }

  my $isCommentedOut;

  if ( StringUtils::str_starts_with( $parts[ PREFIX ], "//" ) or
       StringUtils::str_starts_with( $parts[ PREFIX ], "/*" ) )
  {
    $isCommentedOut = 1;
  }
  else
  {
    $isCommentedOut = 0;
  }

  if ( $isCommentedOut )
  {
    return $line;
  }
  else
  {
    # write_stdout( "Commenting out setting $settingName...\n" );
    return "// Automatically commented out by $changingAgentName: " . $line;
  }
}


#------------------------------------------------------------------------

MiscUtils::entry_point( \&main, SCRIPT_NAME );
