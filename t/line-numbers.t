
use Test::More;

use XML::LibXML;
use Data::Dump;

my $doc = XML::LibXML->load_xml(location => 'D:\\AAAMYFUN2.xml', line_numbers => 1);
my $root = $doc->documentElement();

my @before = ();
for my $node ($root->findnodes('//*')) {
    # warn $node->nodePath,"\n";  # /database/partitions/partition/processes/process/functions/function";
    # is $node->line_number, 21;
    @now = make_path($node);
    dd [ map { $_ ? $_->nodeName : '-' } ctx_change(\@before, \@now) ];
    @before = @now;
}

sub make_path {
    my $node = shift;
    my @context = ();
    while(my $parent = $node->parentNode) {
        unshift @context, $parent;
        $node = $parent;
    }
    return @context;
}

sub ctx_change {
    my ($before, $now) = @_;

    my @ctx = ();
    for my $i (0 .. $#now) {
        my $is_same =  defined $before->[$i]
                    && $now->[$i]->isSameNode($before->[$i]);
        push @ctx, $is_same ? undef : $now->[$i];
    }
    return @ctx;
}

done_testing;

