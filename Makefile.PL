use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Xcruciate::XcruciateConfig',
    VERSION_FROM      => 'lib/Xcruciate/XcruciateConfig.pm', # finds $VERSION
    PREREQ_PM         => {Xcruciate::Utils => 0.06}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Xcruciate/XcruciateConfig.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Howe <melonman@cpan.org>') : ()),
);
