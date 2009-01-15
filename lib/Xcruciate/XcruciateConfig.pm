#! /usr/bin/perl -w

package Xcruciate::XcruciateConfig;
use Exporter;
@ISA = ('Exporter');
@EXPORT = qw();
our $VERSION = 0.05;

use strict;
use Xcruciate::Utils;

=head1 NAME

Xcruciate::XcruciateConfig - OO API for reading xcruciate config files.

=head1 SYNOPSIS

my $config=Xcruciate::XcruciateConfig->new('xcruciate.conf');

my $xacd_path=$config->xacd_path;

my @unit_paths=$config->unit_config_files;

=head1 DESCRIPTION

Xcruciate::XcruciateConfig is part of the Xcruciate project (F<http://www.xcruciate.co.uk>). It provides an
OO interface to an xcruciate configuration file.

The methods all take an optional verbose argument. If this is perlishly true the
methods will show their working to STDOUT.

At present the methods look for configuration errors and die noisily if they find any.
This is useful behaviour for management scripts - continuing to set up server daemons
on the basis of broken configurations is not best practice - but non-fatal error
reporting could be provided if/when an application requires it.

=head1 AUTHOR

Mark Howe, E<lt>melonman@cpan.orgE<gt>

=head2 EXPORT

None

=cut

#Records fields:
#  scalar/list
#  Optional? (1 means 'yes')
#  data type
#  data type specific fields:
#     min, max for numbers
#     required permissions for files/directories

my $xcr_settings =
{
    'config_type',             ['scalar',0,'word'],
    'restart_sleep',           ['scalar',0,'integer',0],
    'start_test_sleep',        ['scalar',0,'integer',0],
    'stop_test_sleep',         ['scalar',0,'integer',0],
    'unit_config_files',       ['list',  0,'abs_file','r'],
    'xacd_path',               ['scalar',0,'abs_file','x'],
    'xted_path',               ['scalar',0,'abs_file','x']
};

=head1 METHODS

=head2 new(config_file_path [,verbose])

Creates and returns an Xcruciate::XcruciateConfig object which can then be queried.

=cut

sub new {
    my $class = shift;
    my $path = shift;
    my $verbose = 0;
    $verbose = shift if defined $_[0];
    my $self = {};

    Xcruciate::Utils::check_path('xcruciate config file',$path,'r');
    print "Attempting to parse xcruciate config file... " if $verbose;
    my $parser = XML::LibXML->new();
    my $xcr_dom = $parser->parse_file($path);
    my @config = $xcr_dom->findnodes("/config/scalar");
    die "Config file doesn't look anything like a config file - 'xcruciate file_help' for some clues" unless $config[0];
    my @config_type = $xcr_dom->findnodes("/config/scalar[\@name='config_type']/text()");
    die "config_type entry not found in unit config file" unless $config_type[0];
    my $config_type = $config_type[0]->toString;
    die "config_type in unit config file is '$config_type' (should be 'xcruciate') - are you confusing xcruciate and unit config files?" unless $config_type eq 'xcruciate';
    my @errors = ();
    foreach my $entry ($xcr_dom->findnodes("/config/*[(local-name() = 'scalar') or (local-name() = 'list')]")) {
	push @errors,sprintf("No name attribute for element '%s'",$entry->nodeName) unless $entry->hasAttribute('name');
	my $entry_record = $xcr_settings->{$entry->getAttribute('name')};
	if (not defined $entry_record) {
	    warn "Unknown xcruciate config entry '" . ($entry->getAttribute('name')) ."'";
	} elsif (not($entry->nodeName eq $entry_record->[0])){
	    push @errors,sprintf("Entry called %s should be a %s not a %s",$entry->getAttribute('name'),$entry_record->[0],$entry->nodeName);
	} elsif ((not $entry->textContent) and ((not $entry_record->[1]) or $entry->textContent!~/^\s*$/s)) {
	    push @errors,sprintf("Entry called %s requires a value",$entry->getAttribute('name'))
	} elsif (($entry->nodeName eq 'scalar')  and $entry_record->[2] and ((not $entry_record->[1]) or $entry->textContent!~/^\s*$/s or $entry->textContent)){
	    push @errors,Xcruciate::Utils::type_check($self,$entry->getAttribute('name'),$entry->textContent,$entry_record);
	} elsif (($entry->nodeName eq 'list') and $entry_record){
	    my @items = $entry->findnodes('item/text()');
	    push @errors,sprintf("Entry called %s requires at least one item",$entry->getAttribute('name')) if ((not $entry_record->[2]) and (not @items));
	    my $count = 1;
	    foreach my $item (@items) {
		push @errors,Xcruciate::Utils::type_check($self,$entry->getAttribute('name'),$item->textContent,$entry_record,$count);
		$count++;
	    }
	}
	push @errors,sprintf("Duplicate entry called %s",$entry->getAttribute('name')) if defined $self->{$entry->getAttribute('name')};
	if ($entry->nodeName eq 'scalar') {
	    $self->{$entry->getAttribute('name')} = $entry->textContent;
	} else {
	    $self->{$entry->getAttribute('name')} = [] unless defined $self->{$entry->getAttribute('name')};
	    foreach my $item ($entry->findnodes('item/text()')) {
		push @{$self->{$entry->getAttribute('name')}},$item->textContent;
	    }
	}
    }
    foreach my $entry (keys %{$xcr_settings}) {
	push @errors,sprintf("No xcruciate entry called %s",$entry) unless ((defined $self->{$entry}) or ($xcr_settings->{$entry}->[1]));
    }
    if (@errors) {
	print join "\n",@errors;
	print "\n";
	die "Errors in xcruciate config file - cannot continue";
    } else {
	bless($self,$class);
	print "done\n" if $verbose;
	return $self;
    }
}

=head2 xcr_file_format_description()

Returns multi-lined human-friendly description of the xcr config file

=cut

sub xcr_file_format_description {
    my $self = shift;
    my $ret = '';
    foreach my $entry (sort keys %{$xcr_settings}) {
	my $record = $xcr_settings->{$entry};
	$ret .= "$entry (";
	$ret .= "optional " if $record->[1];
	$ret .="$record->[0])";
	if (not $record->[2]) {
	} elsif (($record->[2] eq 'integer') or ($record->[2] eq 'float')) {
	    $ret .= " - $record->[2]";
	    $ret .= " >= $record->[3]" if defined $record->[3];
	    $ret .= " and <= $record->[4]" if defined $record->[4];
	} elsif ($record->[2] eq 'ip') {
	    $ret .= " - ip address";
	} elsif ($record->[2] eq 'word') {
	    $ret .= " - word (ie no whitespace)";
	} elsif ($record->[2] eq 'path') {
	    $ret .= " - path (currently a word)";
	} elsif ($record->[2] eq 'xml_leaf') {
	    $ret .= " - filename with an xml suffix";
	} elsif ($record->[2] eq 'xsl_leaf') {
	    $ret .= " - filename with an xsl suffix";
	} elsif ($record->[2] eq 'yes_no') {
	    $ret .= " - 'yes' or 'no'";
	} elsif ($record->[2] eq 'email') {
	    $ret .= " - email address";
	} elsif ($record->[2] eq 'abs_dir') {
	    $ret .= " - absolute directory path with $record->[3] permissions";
	} elsif ($record->[2] eq 'abs_file') {
	    $ret .= " - absolute file path with $record->[3] permissions";
	} elsif ($record->[2] eq 'abs_create') {
	    $ret .= " - absolute file path with $record->[3] permissions for directory";
	}
	$ret .= "\n";
    }
    return $ret;
}

=head2 restart_sleep()

Returns the time to sleep for between stopping and starting during a restart.

=cut

sub restart_sleep {
    my $self = shift;
    return $self->{restart_sleep};
}

=head2 start_test_sleep()

Returns the time to sleep for between starting a process and checking that it started correctly.

=cut

sub start_test_sleep {
    my $self = shift;
    return $self->{start_test_sleep};
}

=head2 stop_test_sleep()

Returns the time to sleep for between killing a process and checking that it died.

=cut

sub stop_test_sleep {
    my $self = shift;
    return $self->{stop_test_sleep};
}

=head2 xacd_path()

Returns the path to the xacd executable.

=cut

sub xacd_path {
    my $self = shift;
    return $self->{xacd_path};
}

=head2 xted_path()

Returns the path to the xted executable.

=cut

sub xted_path {
    my $self = shift;
    return $self->{xted_path};
}

=head2 unit_config_files()

Returns a list of paths to Xacerbate configuration files.

=cut

sub unit_config_files {
    my $self = shift;
    return @{$self->{unit_config_files}};
}

=head1 BUGS

The best way to report bugs is via the Xcruciate bugzilla site (F<http://www.xcruciate.co.uk/bugzilla>).

=head1 PREVIOUS VERSIONS

=over

B<0.01>: First upload

B<0.03>: First upload containing module

B<0.04> Changed minimum perl version to 5.8.8

B<0.05> Warn about unknown entries

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 - 2009 by SARL Cyberporte/Menteith Consulting

This library is distributed under BSD licence (F<http://www.xcruciate.co.uk/licence-code>).

=cut

1;
