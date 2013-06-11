package Catalyst::Controller::DBIC::CRUDFu;
use Moose;
use namespace::autoclean;

use 5.006;
use strict;
use warnings FATAL => 'all';

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

=head1 NAME

Catalyst::Controller::DBIC::CRUDFu - The great new Catalyst::Controller::DBIC::CRUDFu!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Catalyst::Controller::DBIC::CRUDFu;

    my $foo = Catalyst::Controller::DBIC::CRUDFu->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=cut

sub list :Chained('base') :Args(0) :PathPart('list') {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};

    my $tabletext = '<table';
    my %attributes = %{$fu->{list}->{attributes} || {}};
    $tabletext .= sprintf(' %s="%s"',$_,$attributes{$_}) foreach keys %attributes;
    $tabletext .= ">\n";
    if ($fu->{list}->{headers}) {
        $tabletext .= '<tr>';
        for (my $i = 0; $i < scalar(@{$fu->{list}->{columns}}); $i++) {
            $tabletext .= sprintf('<th>%s</th>',$fu->{list}->{headers}->[$i] || '&nbsp;');
        }
        $tabletext .= "</tr>\n";
    }
    my $pkey = $fu->{pkey};
    foreach my $row ($fu->{search}->all()) {
        $tabletext .= '<tr>';
        foreach my $column (@{$fu->{list}->{columns}}) {
            if ($column eq '_edit') {
                $tabletext .= sprintf('<td><a href="%d/edit">Edit</a></td>',$row->$pkey);
            } elsif ($column eq '_delete') {
                $tabletext .= sprintf('<td><a href="%d/delete">Delete</a></td>',$row->$pkey);
            } else {
                $tabletext .= sprintf('<td>%s</td>',$row->$column);
            }
        }
        $tabletext .= "</tr>\n";
    }
    $tabletext .= '</table>';
    $c->stash->{table} = $tabletext;

    $c->stash->{template} = $fu->{template_path}.'/list.tt';
}

sub edit :Chained('object_setup') :PathPart('edit') :Args(0) :FormConfig {
    my ($self, $c) = @_;
    
    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};
    my $object = $c->stash->{object};

    if ($form->submitted_and_valid) {
        $form->model->update($object);

        $c->response->redirect($c->uri_for($self->action_for('list'),
            { mid => $c->set_status_msg("Successfully updated ".$fu->{display_name}) }));
        $c->detach();
    } else {
        $c->forward('form_setup');
        $form->model->default_values($object);
    }
    $c->stash->{template} = $fu->{template_path}.'/edit.tt';
}

sub create :Chained('base') :PathPart('create') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};

    if ($form->submitted_and_valid) {
        my $obj = $fu->{class}->new_result($fu->{defaults} || {});
        $form->model->update($obj);

        $c->response->redirect($c->uri_for($self->action_for('list'), 
            {mid => $c->set_status_msg("New ".$fu->{display_name}." created")}));
        $c->detach();
    } else {
        $c->forward('form_setup');
    }
    $c->stash->{template} = $fu->{template_path}.'/create.tt';
}

sub delete :Chained('object_setup') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;

}

sub object_setup :Chained('base') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $fu = $c->stash->{fu};

    my ($object) = $fu->{search}->search({ $fu->{pkey} => $id })->first;

    unless ($object) {
        $c->response->redirect($c->uri_for($self->action_for('list'),
            { mid => $c->set_status_msg($fu->{display_name}." does not exist or you do not have permissions for it.")}));
        $c->detach;
    }

    $c->stash->{object} = $object;
}

sub form_setup :Private {
    my ($self, $c, $id) = @_;
    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};
}

sub build_fu :Private {
    my ($self, $c, %params) = @_;
    if ($params{name}) {
        $params{class} ||= $c->model('DB::'.$params{name});
        my $name = $params{name};
        $name =~ s/:://g;
        $params{display_name} ||= lc($name);
    }
    $params{pkey} ||= 'id';
    $params{search} = $params{class}->search() unless $params{search};
    unless ($params{template_path}) {
        if ($params{templates} && $params{templates} eq 'custom') {
            my $listpath = $self->action_for('list');
            warn $listpath;
            $listpath =~ s/list$//;
            $params{template_path} = $listpath;
        } else {
            $params{template_path} = 'elements/fu/';
        }
    }
    $c->stash->{fu} = \%params;
}

sub base :Chained('/') :PathPart('objectfu') :CaptureArgs(0) {
    my ($self, $c) = @_;

}

sub index :Path {
    my ($self, $c) = @_;
    $c->response->redirect($c->uri_for($self->action_for('list')));
    $c->detach;
}

=head1 AUTHOR

Josh Ballard, C<< <josh at oofle.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalyst-controller-dbic-crudfu at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Controller-DBIC-CRUDFu>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Catalyst::Controller::DBIC::CRUDFu


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Catalyst-Controller-DBIC-CRUDFu>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Catalyst-Controller-DBIC-CRUDFu>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Catalyst-Controller-DBIC-CRUDFu>

=item * Search CPAN

L<http://search.cpan.org/dist/Catalyst-Controller-DBIC-CRUDFu/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Josh Ballard.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Catalyst::Controller::DBIC::CRUDFu
