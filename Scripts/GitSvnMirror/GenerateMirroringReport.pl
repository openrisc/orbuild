#!/usr/bin/perl

=head1 OVERVIEW

Generates an HTML report of the last update of the OpenRISC git svn mirrors.

=head1 USAGE

perl GenerateMirroringReport.pl <reports dir> <git base dir>  <makefile report filename> <html output filename>

=head1 OPTIONS

-h, --help, --version, --license

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 FEEDBACK

Please send feedback to rdiezmail-openrisc at yahoo.de

=head1 LICENSE

Copyright (C) 2011 R. Diez

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
use HTML::Entities;
use URI::Escape;
use FindBin;
use File::Glob;

use constant THIS_SCRIPT_DIR => $FindBin::Bin;

use lib THIS_SCRIPT_DIR . "/../PerlModules";
use MiscUtils;
use FileUtils;
use StringUtils;
use ReportUtils;
use AGPL3;

use constant SCRIPT_NAME => $0;

use constant APP_NAME    => "GenerateReport.pl";
use constant APP_VERSION => "0.10";  # If you update it, update also the perldoc text above if needed.

use constant REPORT_EXTENSION => ".report";
use constant LOG_EXTENSION    => ".txt";


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

  if ( scalar( @ARGV ) != 4 )
  {
    die "Invalid number of arguments. Run this program with the --help option for usage information.\n";
  }

  my $reportsDir = shift @ARGV;
  my $gitBaseDir = shift @ARGV;
  my $makefileReportFilename = shift @ARGV;
  my $htmlOutputFilename = shift @ARGV;

  write_stdout( "Collecting reports...\n" );

  my %makefileReportEntries;
  ReportUtils::load_report( $makefileReportFilename, \%makefileReportEntries );

  my $makefileUserFriendlyName = $makefileReportEntries{"UserFriendlyName"};

  my @allReports;
  # At the moment, the makefile report is in the same directory as all others,
  # so it will be found again later.
  #   push @allReports, \%makefileReportEntries;

  ReportUtils::collect_all_reports( $reportsDir, REPORT_EXTENSION, \@allReports );

  my @sortedReports = ReportUtils::sort_reports( \@allReports, $makefileUserFriendlyName );

  write_stdout( "Generating HTML report...\n" );

  my $injectedHtml = "";

  foreach my $report ( @sortedReports )
  {
    $injectedHtml .= process_report( $report, $gitBaseDir, $makefileUserFriendlyName );
  }

  my $htmlTemplateFilename = FileUtils::cat_path( THIS_SCRIPT_DIR, "ReportTemplate.html" );

  my $htmlText = FileUtils::read_whole_binary_file( $htmlTemplateFilename );

  ReportUtils::check_valid_html( $htmlText );

  ReportUtils::replace_marker( \$htmlText, "LAST_UPDATE_START_TIME", $makefileReportEntries{"StartTimeUTC"} );
  ReportUtils::replace_marker( \$htmlText, "GIT_REPOSITORY_TABLE"  , $injectedHtml );

  ReportUtils::check_valid_html( $htmlText );

  FileUtils::write_string_to_new_file( $htmlOutputFilename, $htmlText );
  
  write_stdout( "HTML report finished, the resulting file is: $htmlOutputFilename\n" );

  return MiscUtils::EXIT_CODE_SUCCESS;
}


sub process_report ( $ $ )
{
  my $report      = shift;
  my $gitBaseDir  = shift;
  my $makefileUserFriendlyName = shift;

  my $logFilename = $report->{ "LogFile" };
  my $userFriendlyName = $report->{ "UserFriendlyName" };

  my ( $volume, $directories, $logFilenameOnly ) = File::Spec->splitpath( $logFilename );

  my $description;
  my $gitCloneUrlCellContents;

  if ( $userFriendlyName eq $makefileUserFriendlyName )
  {
    $description = "Combined log file for the whole process.";
    $gitCloneUrlCellContents = "-";
  }
  else
  {
    # Derive the git directory path from the log filename.

    if ( not StringUtils::str_ends_with( $logFilenameOnly, LOG_EXTENSION ) )
    {
      die "Internal error processing the log filename.\n";
    }

    my $gitDirname = substr( $logFilenameOnly, 0, length($logFilenameOnly) - length(LOG_EXTENSION) );

    my $descriptionFilename = FileUtils::cat_path( $gitBaseDir, $gitDirname, ".git", "description" );

    $description = StringUtils::trim_blanks( FileUtils::read_whole_binary_file( $descriptionFilename ) );

    my $orbuildGitSvnInitFilename = FileUtils::cat_path( $gitBaseDir, $gitDirname, ".git", "OrbuildGitSvnInit" );

    my $gitSvnInitContents = StringUtils::trim_blanks( FileUtils::read_whole_binary_file( $orbuildGitSvnInitFilename ) );

    my $gitSvnInit  = encode_entities( $gitSvnInitContents );
    my $gitClone = encode_entities( "git clone git://openrisc.net/git-svn-mirrors/" . $gitDirname );

    my $sizeInit  = "style=\"width:100%;\"";
    my $sizeClone = "style=\"width:100%;\"";

    $gitCloneUrlCellContents = "<div style=\"padding-right: 5px;\">";
    $gitCloneUrlCellContents.= "<input type=\"text\" spellcheck=\"false\" $sizeInit value=\"" .
                               $gitSvnInit .
                               "\"/>" .
                               "\n";

    $gitCloneUrlCellContents.="<br/>";

    $gitCloneUrlCellContents.= "<input type=\"text\" spellcheck=\"false\" $sizeClone value=\"" .
                               $gitClone .
                               "\"/>" .
                               "</div>" .
                               "\n";
  }

  my $html = "<tr>\n";

  $html.= text_cell( $userFriendlyName );
  $html.= text_cell( $description );

  if ( $report->{ "ExitCode" } == 0 )
  {
    $html.= "<td ALIGN=\"center\" BGCOLOR=\"#00FF00\">" .
            "<font color=\"black\">" .
            "<strong>" .
            "OK" .
            "</strong>" .
            "</font>" . "</td>\n";
  }
  else
  {
    $html.= "<td ALIGN=\"center\" BGCOLOR=\"#FF0000\">" .
            "<font color=\"white\">" .
            "<strong>" .
            "FAILED" .
            "</strong>" .
            "</font>" . "</td>\n";
  }

  my $link2 = encode_entities( $logFilenameOnly );  # Absolute link: "file://" . encode_entities( $logFilename );
  $html.= link_cell( $link2, "Log&nbsp;File" );

  $html.= "<td>$gitCloneUrlCellContents</td>\n";

  $html.= "</tr>\n";
  $html.= "\n";

  return $html;
}


sub text_cell ( $ )
{
  my $contents = shift;
  return "<td>" . encode_entities( $contents ) . "</td>\n";
}


sub link_cell ( $ $ )
{
  my $link = shift;
  my $text = shift;

  return "<td> <a href=\"$link\">$text</a> </td>";
}


#------------------------------------------------------------------------

MiscUtils::entry_point( \&main, SCRIPT_NAME );
