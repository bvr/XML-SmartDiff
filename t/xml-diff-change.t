
use lib '../lib';
use Test::More;
use Data::Dump qw{dump};

my $a = <<END_XML;
<doc>
    <Function Name="A" Desc="This"></Function>
    <Function Name="D" Desc="This"></Function>
    <Function Name="B" Desc="This"></Function>
</doc>
END_XML

my $b = <<END_XML;
<doc>
    <Function Name="A" Desc="That"></Function>
    <Function Name="B" Desc="That"></Function>
    <Function Name="C" Desc="That"></Function>
</doc>
END_XML


use XML::SmartDiff;

my $diff = XML::SmartDiff->new();

my $it = $diff->compare(string => $a, string => $b);
while(my $change = $it->next) {
    warn $change->to_string;
}

done_testing;
