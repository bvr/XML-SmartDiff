
use 5.010;

package XML::SmartDiff;
# ABSTRACT: Compares two XML documents smart way
use Moose;

use Carp             qw(croak);
use XML::LibXML;
use Iterator::Simple qw(iterator);
use Try::Tiny        qw(try catch);
use List::MoreUtils  qw(uniq);

use XML::SmartDiff::Change;

=head1 SYNOPSIS

    use XML::SmartDiff;

    my $diff = XML::SmartDiff->new();

    my $it = $diff->compare('file1.xml', 'file2.xml');
    while(my $change = $it->next) {
        print $change->to_string;
    }

=attr target_class

Set class for individual changes. Default to C<XML::SmartDiff::Change>

=cut

has target_class => (
    is      => 'ro',
    default => 'XML::SmartDiff::Change'
);

=attr parser_options

HashRef of options passed to L<XML::LibXML> constructor.

=cut

has parser_options => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { { line_numbers => 1 } }
);

=attr include_context

Boolean. Controls whether L</compare> iterator returns also context objects.
Enabled by default.

=cut

has include_context => (is => 'ro', isa => 'Bool', default => 0);

=method compare

    my $change_it = $diff->compare('filename1.xml', 'filename2.xml');
    my $change_it = $diff->compare($filehandle1,    $filehandle2);
    my $change_it = $diff->compare(location => 'filename1.xml', location => 'filename2.xml');
    my $change_it = $diff->compare(string => '<doc><elem/></doc>', string => '<doc><elem/></doc>');

Returns iterator to compare two XML documents.

=cut

sub compare {
    my $self = shift;
    my $ext_syntax = @_ == 4 ? 1
                   : @_ == 2 ? 0
                   :           croak("Bad number of parameters: @_");

    my @param1 = $ext_syntax ? splice(@_,0,2) : $self->_detect(shift);
    my @param2 = $ext_syntax ? splice(@_,0,2) : $self->_detect(shift);

    # open both documents
    my ($d1, $d2);
    try {
        $d1 = XML::LibXML->load_xml(@param1, %{$self->parser_options})->documentElement;
        $d2 = XML::LibXML->load_xml(@param2, %{$self->parser_options})->documentElement;
    }
    catch {
        croak $_;
    };

    my $target_class = $self->target_class;

    my @process_queue = ( [$d1, $d2] );
    my @return = ();

    my $changes_it = iterator {
        while(1) {

            return shift @return if @return;
            return unless @process_queue;       # we are done

            my $pair = pop @process_queue;

            unless (defined $pair->[0]) {
                push @return,
                    $target_class->new(action => 'add', right => $pair->[1]);
                next;
            }

            unless (defined $pair->[1]) {
                push @return,
                    $target_class->new(action => 'delete', left => $pair->[0]);
                next;
            }

            # make list of children
            my %c1 = %{ $self->_elements_of($pair->[0]) };
            my %c2 = %{ $self->_elements_of($pair->[1]) };

            # work on attributes
            if(my @attr = $self->_attributes_differ(@$pair)) {
                push @return,
                    $target_class->new(
                        action => 'change',
                        left   => $pair->[0],
                        right  => $pair->[1],
                        desc   => [ @attr ],
                    );
            }

            # TODO: check if text differ

            # fill process queue with elements
            # "reverse" is to make sure order of child is kept in the stack
            for my $key (reverse sort +uniq keys(%c1), keys(%c2)) {
                push @process_queue, [ $c1{$key}, $c2{$key} ];
            }
        }
    };

    return $changes_it unless $self->include_context;

    # iterator to add context items
    my @current_ctx = ();
    my @return_ctx  = ();
    return iterator {
        while(1) {
            return shift @return_ctx if @return_ctx;


        }
    }
}

sub _attributes_differ {
    my ($self, $e1, $e2) = @_;

    # TODO: Look for better checking of attribute names
    my @differ;
    for my $attr (sort +uniq map { $_->nodeName } $e1->attributes, $e2->attributes) {
        push @differ, $attr
            if ($e1->getAttribute($attr)//'') ne ($e2->getAttribute($attr)//'');
    }
    return @differ;
}

sub _elements_of {
    my ($self, $elem) = @_;

    my %ret = ();
    my @elements = grep { $_->nodeType == XML_ELEMENT_NODE } $elem->childNodes;
    for my $el (@elements) {
        my $key = $self->elem_key($el);
        warn "Duplicate key \"$key\"\n" if exists $ret{$key};
        $ret{$key} = $el;
    }
    return \%ret;
}


=method elem_key

Returns string key to identify identical object. Can be subclassed to enable
different set of elements.

=cut

sub elem_key {
    my ($self, $elem) = @_;

    # TODO: probably move this method to a callback with some reasonable default

    my $key = $elem->nodeName;
    my $name_attr = $elem->getAttribute('Name');
    given($key) {

        # Data Dictionary elements
        when('ProducedBy') { $name_attr = $elem->getAttribute('Function'); }
        when('ConsumedBy') { $name_attr = $elem->getAttribute('Function'); }
        when('SourceSmtObject')      { $name_attr = $elem->getAttribute('ID'); }
        when('DestinationSmtObject') { $name_attr = $elem->getAttribute('ID'); }

        # Constant Dictionary elements
        when('Constants')  { $name_attr = $elem->getAttribute('Relatedto'); }
        when('Value')      { $name_attr = $elem->getAttribute('Setup'); }
        when('Setup')      { $name_attr = $elem->getAttribute('ID'); }

    }
    $key .= "-".$name_attr if $name_attr;
    return $key;
}


# detect type of item and return pair suitable for passing to XML::LibXML->load_xml
sub _detect {
    my ($self,$item) = @_;

    if(ref $item eq "GLOB")            { return (IO       => $item) }
    if(!ref($item) && $item =~ /[<>]/) { return (string   => $item) }
    return                                      (location => $item);
}

=head1 SEE ALSO

L<XML::LibXML>

=cut

1;
