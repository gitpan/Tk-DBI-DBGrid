#	Database Grig - browsing database using "SELECT..." string
#
#	Testing on ActivePerl, Oracle
#
#	Author: Vadim Likhota, <vadim-lvv@yandex.ru>
#
#	v.0.01 - 16.12.2004


package Tk::DBI::DBGrid;

use vars qw($VERSION);
$VERSION = '0.01';

use Tk;
use DBI;

use base qw/Tk::Frame Tk::Label Tk::Entry Tk::Scrollbar/;
use strict;

Construct Tk::Widget 'DBGrid';


#sub ClassInit
#{
#	my ($class,$mw) = @_;
#
#	$class->SUPER::ClassInit($mw);
#
#	$mw->bind($class,'<Key-Tab>' ,'NoOp');
#	$mw->bind($class,'<Return>' ,'NoOp');
#	$mw->bind($class,'<Key-Up>' ,'NoOp');
#	$mw->bind($class,'<Key-Down>' ,'NoOp');
# 
#	return $class;
#}




sub Populate {
	my ($w, $args) = @_;
	$w->{dbh} = delete $args->{-dbh} or die "Tk:DBI:DBGrid: No -dbh\n";
	$w->{sql} = delete $args->{-sql} or die "Tk:DBI:DBGrid: No -sql\n";
	$w->{font} = exists $args->{-font} ? delete $args->{-font} : 'Courier 9';
	$w->{maxrow} = (exists $args->{-maxrow} ? delete $args->{-maxrow} : 10) - 1;
	$w->{titlcolor} = exists $args->{-titlbg} ? delete $args->{-titlbg} : 'SystemButtonFace';
	$w->{seltitlcolor} = exists $args->{-seltitlbg} ? delete $args->{-seltitlbg} : 'SystemHighlight';
	$w->{edit} = exists $args->{-edit} ? delete $args->{-edit} : 0;
	$w->{tablename} = exists $args->{-tablename} ? delete $args->{-tablename} : '';
	$w->{pkey} = exists $args->{-pkey} ? delete $args->{-pkey} : undef;
	$w->{pkey} = $w->{pkey}[0] if $w->{pkey};
	$w->{cellformat} = exists $args->{-cellformat} ? delete $args->{-cellformat} : undef;
	$w->{insfunc} = exists $args->{-insfunc} ? delete $args->{-insfunc} : undef;
	$w->{updfunc} = exists $args->{-updfunc} ? delete $args->{-updfunc} : undef;
	$w->{delfunc} = exists $args->{-delfunc} ? delete $args->{-delfunc} : undef;
	$w->{fkeys}->{fk} = exists $args->{-fkeys} ? delete $args->{-fkeys} : undef;
	$w->SUPER::Populate($args);
	$w->{vscroll} = $w->Scrollbar( -command => [vpos => $w] )->pack( -side => 'right', -fill => 'y' );
	$w->{frame} = $w->Frame( -bd => 1, -relief => 'sunken' )->pack( -fill => 'both', -expand => 1 );
	{
		my $sql = $w->{sql};
		$sql =~ tr/a-z/A-Z/;
		if ( $sql =~ /(INSERT|UPDATE|DELETE)/ ) {
			die "Tk:DBI:DBGrid: Working with SELECT-QUERY only (finding $1)\n";
		}
		if ( $w->{edit} and not $w->{tablename} and $sql =~ /FROM (\w+)/) {
			$w->{tablename} = $1;
		}
	}
	if ( $w->{edit} ) {
		my $sql = $w->{sql};
		$sql =~ tr/a-z/A-Z/;
#		$w->{edit} = 0 unless ($sql =~ /FROM \w+ (WHERE|ORDER)/ or $sql =~ /FROM \w+ *$/ or $w->{tablename});
		$w->{edit} = 0 if $sql =~ /SELECT .*(OVER|SUM\(|COUNT\(|AVG\().* FROM/; # OVER - analitic function in Oracle
		$w->{edit} = 0 if $sql =~ /GROUP/;
		unless ( $w->{pkey} ) {
			$w->{edit} = 0;
		}
		else {
			$w->{pkey} =~ tr/a-z/A-Z/;
		}
		$w->{edit} = 0 if ( $sql =~ /(JOIN|UNION)/ and not $w->{tablename} and not $w->{pkey} );
		print STDERR "Tk:DBI:DBGrid: This query too complex for edit table ($sql)\n" unless $w->{edit};
	}
#	print "t = $w->{tablename}, kp = $w->{pkey}, edit = $w->{edit}\n";


	# loading data from database
	my $sth = $w->{dbh}->prepare($w->{sql});
	$sth->execute;
	$w->{table}->{numfields} = $sth->{NUM_OF_FIELDS} - 1;
	foreach ( 0..$w->{table}->{numfields} ) {
		$w->{table}->{name}->[$_] = $sth->{NAME}->[$_];
		if ( $w->{edit} and $w->{table}->{name}->[$_] eq $w->{pkey} ) {
			$w->{edit} = 2;
			$w->{pkeynum} = $_;
		}
		$w->{table}->{lenth}->[$_] = $sth->{PRECISION}->[$_];
		$w->{table}->{type}->[$_] = $sth->{TYPE}->[$_];
		$w->{table}->{null}->[$_] = $sth->{NULLABLE}->[$_];
		#  1 - char, nchar
		#  3 - integer, numeric
		# 12 - varchar, varchar2, nvarchar2
		# 40 - clob
		# 93 - date(time), timestamp
		# -1 - long
		# -9104 - rowid, urowid
		# -9114 - bfile
#		$w->{table}->{lenth}->[$_] = 20 if $w->{table}->{type}->[$_] == 93 and $w->{table}->{lenth}->[$_] > 20;
		if ( $w->{table}->{type}->[$_] == 1 or $w->{table}->{type}->[$_] == 12 ) {
			$w->{table}->{justify}->[$_] = 'left';
		}
		elsif ( $w->{table}->{type}->[$_] == 3 ) {
			$w->{table}->{justify}->[$_] = 'right';
		}
		else {
			$w->{table}->{justify}->[$_] = 'center';
		}
	} # foreach
	if ( $w->{edit} and $w->{edit} == 1 ) {
		print STDERR "Tk:DBI:DBGrid: Can't find primary key ($w->{pkey}) in query ($w->{sql})\n";
		$w->{edit} = 0;
	}
	else {
		$w->{edit} = 1;
	}
	if ( $w->{cellformat} ) {
		foreach ( 0..$w->{table}->{numfields} ) {
			$w->{table}->{lenth}->[$_] = $w->{cellformat}->[$_]{width} if $w->{cellformat}->[$_]{width};
			$w->{table}->{justify}->[$_] = $w->{cellformat}->[$_]{justify} if $w->{cellformat}->[$_]{justify};
			if ( $w->{edit} and $w->{cellformat}->[$_]{edit} and $w->{pkeynum} != $_ ) {
				$w->{table}->{edit}->[$_] = 1;
			}
			else {
			  $w->{table}->{edit}->[$_] = 0;
			}
		}
	}
	my $i = 0;
	while ( my @row = $sth->fetchrow_array ) {
		foreach ( 0..$#row ) {
			$w->{table}->{data}->[$i][$_] = $row[$_];
		}
		$i++;
	}
	$w->{table}->{numrows} = --$i;
	$w->{table}->{visrows} = $w->{table}->{numrows} < $w->{maxrow} ? $w->{table}->{numrows} : $w->{maxrow};
	$sth->finish;
	$w->{table}->{modif} = 0;

	# keys
	$w->{fkeys}->{ins} = 'Key-F5';
	$w->{fkeys}->{del} = 'Key-F8';
	if ( $w->{fkeys}->{fk} ) {
		$w->{fkeys}->{ins} = $w->{fkeys}->{fk}->{ins} if $w->{fkeys}->{fk}->{ins};
		$w->{fkeys}->{del} = $w->{fkeys}->{fk}->{del} if $w->{fkeys}->{fk}->{del};
	}

	
	# init position vars
	$w->{pos}->{prev} = 0;
	$w->{pos}->{preh} = 0;
	$w->{pos}->{visb} = 0;
	$w->{pos}->{vise} = $w->{table}->{visrows};
	$w->{pos}->{curv} = 0;
	$w->{pos}->{curh} = 0;

	$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, 0, 0);
	

	# reflection data
	$w->{titlframe} = $w->{frame}->Frame->pack( -fill => 'x' );
	$w->{titlframe}->Label( -text => ' ', -font => $w->{font}, -width => 1, -bd => 1, -relief => 'ridge' )->pack( -side => 'left');
	foreach ( 0..$w->{table}->{numfields} ) {
		$w->{titl}->[$_] = $w->{titlframe}->Label( -text => $w->{table}->{name}->[$_], -font => $w->{font}, -width => $w->{table}->{lenth}->[$_], -bd => 1, -relief => 'ridge', -bg => $w->{titlcolor} )->pack( -side => 'left');
		$w->{titl}->[$_]->{h} = $_;
		$w->{titl}->[$_]->bind('<Button>' => sub { shift->configure( -relief => 'groove' ) });
		$w->{titl}->[$_]->bind('<ButtonRelease>' => sub { 
			my $lb = shift;
			my $w = (($lb->parent)->parent)->parent;
			$lb->configure( -relief => 'ridge' );
			$w->{pos}->{preh} = $w->{pos}->{curh};
			$w->{pos}->{curh} = $lb->{h};
			$w->{titl}->[$w->{pos}->{preh}]->configure( -bg => $w->{titlcolor} );
			$w->{titl}->[$lb->{h}]->configure( -bg => $w->{seltitlcolor} );
		});	# bind
	}		# foreach
	foreach my $j ( 0..$w->{table}->{visrows} ) {
		$w->{rowframe}->[$j] = $w->{frame}->Frame->pack( -fill => 'x' );
		$w->{rowframel}->[$j] = $w->{rowframe}->[$j]->Label( -text => '>', -font => $w->{font}, -width => 1, -bd => 1, -relief => 'ridge', -bg => $w->{titlcolor} )->pack( -side => 'left');
		$w->{rowframel}->[$j]->{v} = $j;
		$w->{rowframel}->[$j]->bind('<Button>' => sub { shift->configure( -relief => 'groove' ) });
		$w->{rowframel}->[$j]->bind('<ButtonRelease>' => sub { 
			my $lb = shift;
			my $w = (($lb->parent)->parent)->parent;
			$lb->configure( -relief => 'ridge' );
			$w->{pos}->{prev} = $w->{pos}->{curv};
			$w->{pos}->{curv} = $lb->{v} + $w->{pos}->{visb};
			$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, $w->{pos}->{curv}, $w->{pos}->{curv});
			$w->{rowframel}->[$w->{pos}->{prev} - $w->{pos}->{visb}]->configure( -bg => $w->{titlcolor} );
			$w->{rowframel}->[$lb->{v}]->configure( -bg => $w->{seltitlcolor} );
		});	#bind
		foreach my $k ( 0..$w->{table}->{numfields} ) {
			if ( $w->{table}->{edit}->[$k] ) {
				$w->{rowframee}->[$j][$k] = $w->{rowframe}->[$j]->Entry( -font => $w->{font}, -width => $w->{table}->{lenth}->[$k], -justify => $w->{table}->{justify}->[$k], -bd => 1, -relief => 'groove' )->pack( -side => 'left');
				$w->{rowframee}->[$j][$k]->insert(0, $w->{table}->{data}->[$j][$k]);
				$w->{rowframee}->[$j][$k]->{h} = $k;
				$w->{rowframee}->[$j][$k]->{v} = $j;

				$w->{rowframee}->[$j][$k]->bind('<FocusIn>' => sub {
					my $en = shift;
					$w->{pos}->{prev} = $w->{pos}->{curv};
					$w->{pos}->{preh} = $w->{pos}->{curh};
					$w->{pos}->{curv} = $en->{v} + $w->{pos}->{visb};
					$w->{pos}->{curh} = $en->{h};
					$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, $w->{pos}->{curv}, $w->{pos}->{curv});
					$w->{titl}->[$en->{h}]->configure( -bg => $w->{seltitlcolor} );
					$w->{rowframel}->[$en->{v}]->configure( -bg => $w->{seltitlcolor} );
#					print "0 : pre = $w->{pos}->{prev}, cur = $w->{pos}->{curv}\n";
					if ( $w->{pos}->{prev} != $w->{pos}->{curv} and $w->{table}->{modif} ) {
						if ( $w->{updfunc} ) {
							my @row;
							foreach my $n ( 0..$w->{table}->{numfields} ) {
								$row[$n] = $w->{table}->{data}->[$w->{pos}->{prev}][$n];
							}
							&{$w->{updfunc}}(@row);
						}
						$w->{table}->{modif} = 0;
					}
				});

				$w->{rowframee}->[$j][$k]->bind('<FocusOut>' => sub {
					my $en = shift;
					if ( $w->{table}->{data}->[$en->{v}+$w->{pos}->{visb}][$en->{h}] ne $en->get ) {
						$w->{table}->{modif} = 1;
						$w->{table}->{data}->[$en->{v}+$w->{pos}->{visb}][$en->{h}] = $en->get;
					}
					$w->{titl}->[$en->{h}]->configure( -bg => $w->{titlcolor} );
					$w->{rowframel}->[$en->{v}]->configure( -bg => $w->{titlcolor} );
				});

				$w->{rowframee}->[$j][$k]->bind('<Key-Up>' => sub { 
					my $en = shift;
					if ( $en->{v} > 0 ) {
						$w->{rowframee}->[$j-1][$en->{h}]->focus;
					}
					elsif ( $w->{pos}->{curv} > 0 ) {
						$w->{pos}->{prev} = $w->{pos}->{curv};
						$w->{pos}->{curv}--;
						$w->{rowframel}->[$w->{pos}->{prev} - $w->{pos}->{visb}]->configure( -bg => $w->{titlcolor} );
						$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, $w->{pos}->{curv}, $w->{pos}->{curv});
						$w->vlist;
						$w->{rowframel}->[$w->{pos}->{curv} - $w->{pos}->{visb}]->configure( -bg => $w->{seltitlcolor} );
					}
				} );

				$w->{rowframee}->[$j][$k]->bind('<Key-Down>' => sub { 
					my $en = shift;
					if ( $en->{v} < $w->{table}->{visrows} ) {
						$w->{rowframee}->[$en->{v}+1][$en->{h}]->focus;
					}
					elsif ( $w->{pos}->{curv} < $w->{table}->{numrows} ) {
						$w->{pos}->{prev} = $w->{pos}->{curv};
						$w->{pos}->{curv}++;
						$w->{rowframel}->[$w->{pos}->{prev} - $w->{pos}->{visb}]->configure( -bg => $w->{titlcolor} );
						$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, $w->{pos}->{curv}, $w->{pos}->{curv});
						$w->vlist;
						$w->{rowframel}->[$w->{pos}->{curv} - $w->{pos}->{visb}]->configure( -bg => $w->{seltitlcolor} );
					}
				} );
				if ( $w->{insfunc} ) {
					$w->{rowframee}->[$j][$k]->bind('<'.$w->{fkeys}->{ins}.'>' => sub {
						&{$w->{insfunc}}("error", "for future reliase", "еще не работает");
						
					});
				}
				if ( $w->{delfunc} ) {
					$w->{rowframee}->[$j][$k]->bind('<'.$w->{fkeys}->{del}.'>' => sub {
						&{$w->{delfunc}}($w->{table}->{data}->[$w->{pos}->{curv}][0]);
					});
				}

			}
			else { # edit == 0
				$w->{rowframee}->[$j][$k] = $w->{rowframe}->[$j]->Label( -text => $w->{table}->{data}->[$j][$k], -font => $w->{font}, -width => $w->{table}->{lenth}->[$k], -bd => 1, -relief => 'groove', -bg => 'white' )->pack( -side => 'left');
			}
		}		# $k
	}		# $j


	$w->Advertise('frame' => $w->{frame});
	$w->Advertise('vscroll' => $w->{vscroll});
	$w->Delegates(DEFAULT => $w->{frame});
	$w->ConfigSpecs(
	  -vpos     => [qw/CALLBACK vpos Vpos/, 0],
	  -vlist    => [qw/METHOD vlist Vlist/, undef],
		'DEFAULT' => [$w->{frame}]
	);

	return $w;
} # end Populate



sub vpos {
	my ($w, $addpos) = @_;
	$addpos = 0 if $addpos < 0;
	$addpos = $w->{table}->{numrows} if $addpos > $w->{table}->{numrows};
	if ( ($addpos-$w->{pos}->{visb}) >= 0 and ($addpos-$w->{pos}->{visb}) <= $w->{table}->{visrows} ) {
		$w->{rowframee}->[$addpos-$w->{pos}->{visb}][$w->{pos}->{curh}]->focus;
	}
	else {
		$w->{pos}->{prev} = $w->{pos}->{curv};
		$w->{pos}->{curv} = $addpos;
		$w->{rowframel}->[$w->{pos}->{prev} - $w->{pos}->{visb}]->configure( -bg => $w->{titlcolor} );
		$w->{vscroll}->set($w->{table}->{numrows}, $w->{maxrow}, $w->{pos}->{curv}, $w->{pos}->{curv});
		$w->vlist;
		$w->{rowframel}->[$w->{pos}->{curv} - $w->{pos}->{visb}]->configure( -bg => $w->{seltitlcolor} );
	}
}



sub vlist {
	my ( $w ) = @_;

	if ( $w->{pos}->{curv} < $w->{pos}->{visb} or $w->{pos}->{curv} > $w->{pos}->{vise} ) {
		my $addlist;
		if ( $w->{pos}->{curv} < $w->{pos}->{visb} ) {
			$addlist = $w->{pos}->{curv};
		}
		else {
			$addlist = $w->{pos}->{curv} - $w->{table}->{visrows};
		}
		$w->{pos}->{visb} = $addlist;
		$w->{pos}->{vise} = $addlist + $w->{table}->{visrows};
		foreach my $i ( 0..$w->{table}->{visrows} ) {
			foreach my $j ( 0..$w->{table}->{numfields}) {
				if ( $w->{table}->{edit}->[$j] ) {
					$w->{rowframee}->[$i][$j]->delete(0, 'end');
					$w->{rowframee}->[$i][$j]->insert('end', $w->{table}->{data}->[$i+$addlist][$j]);
				}
				else {
					$w->{rowframee}->[$i][$j]->configure( -text => $w->{table}->{data}->[$i+$addlist][$j]);
				}	
			}
		}
	} # if
} # end vlist




1;



__END__

