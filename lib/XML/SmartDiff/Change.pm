
use 5.010;

package XML::SmartDiff::Change;
# ABSTRACT: Result of comparison of two nodes

use Moose;
use List::MoreUtils qw(zip natatime);
use XML::SmartDiff;
use Moose::Util::TypeConstraints;

enum Actions => [qw(change add delete context)];

has action => (is => 'ro', isa => 'Actions');
has left   => (is => 'ro', isa => 'XML::LibXML::Node', predicate => 'has_left');
has right  => (is => 'ro', isa => 'XML::LibXML::Node', predicate => 'has_right');
has desc   => (is => 'ro', predicate => 'has_desc');

no Moose::Util::TypeConstraints;

sub to_string {
    my $self = shift;

    my @action = ($self->action);
    my @left   = $self->has_left  ? split(/\n/, _stringify($self->left )) : ();
    my @right  = $self->has_right ? split(/\n/, _stringify($self->right)) : ();
    my @desc   = ($self->desc);

    my $it = natatime 4, zip @action, @left, @right, @desc;
    my $ret = '';
    while(my @blocks = map { substr($_ // '',0,50) } $it->()) {
        $ret .= sprintf("| %-10s | %-50s | %-50s | %-20s |\n", @blocks);
    }
    $ret .= sprintf("+-%-10s-+-%-50s-+-%-50s-+-%-20s-+\n", "-"x10, "-"x50, "-"x50, "-"x20);
    $ret;
}

sub _stringify {
    my $node = shift;
    my @attrs = sort map { $_->nodeName } $node->attributes();
    return join("\n", $node->nodeName, map { "  $_: ".$node->getAttribute($_) } @attrs);
}

1;

