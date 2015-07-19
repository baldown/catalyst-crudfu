package Catalyst::Controller::DBIC::CRUDFu;
use Moose;
use namespace::autoclean;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Try::Tiny;
use File::ShareDir qw(dist_dir);

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

sub list_redirect :Private {
    my ($self, $c) = @_;
    my $path = $c->req->uri;
    my $action = $c->action->name;
    $path =~ s/\?.*$//;
    $path =~ s/$action$//;
    $path =~ s|/\d+/$|/|;
    $path .= 'list';
    $c->response->redirect($path);
    $c->detach;
}

sub list :Chained('base') :Args(0) :PathPart('list') {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};

    my $tabletext = '<table';
    my %attributes = %{$fu->{list}->{attributes} || {}};
    $tabletext .= sprintf(' %s="%s"',$_,$attributes{$_}) foreach keys %attributes;
    $tabletext .= ">\n";
    $fu->{list}->{column_class} //= [];
    if ($fu->{list}->{headers}) {
        $tabletext .= '<tr>';
        for (my $i = 0; $i < scalar(@{$fu->{list}->{columns}}); $i++) {
            my $class = $fu->{list}->{column_class}->[$i] ? sprintf(' class="%s"', $fu->{list}->{column_class}->[$i]) : '';
            $tabletext .= sprintf('<th%s>%s</th>', $class, $fu->{list}->{headers}->[$i] || '&nbsp;');
        }
        $tabletext .= "</tr>\n";
    }
    my $pkey = $fu->{pkey};
    
    $c->stash->{page_number} = int($c->req->param('page') || 1);
    my $page = $c->stash->{page_number} - 1;
    my $per_page = 20;
    $c->stash->{total_pages} = int($fu->{search}->count / $per_page) + 1;
    my $rs = $fu->{search}->search({
    
    },{
      rows => $per_page,
      offset => $per_page * $page,
    });
    
    foreach my $row ($rs->all()) {
        $tabletext .= '<tr>';
        #foreach my $column (@{$fu->{list}->{columns}}) {
        for (my $i = 0; $i < scalar(@{$fu->{list}->{columns}}); $i++) {    
            my $column = $fu->{list}->{columns}->[$i];
            my $class = $fu->{list}->{column_class}->[$i] ? sprintf(' class="%s"', $fu->{list}->{column_class}->[$i]) : '';
            if (ref($column) eq 'ARRAY') {
                my ($actionpath, $title) = @$column;
                $tabletext .= sprintf('<td%s><a title="%s" href="%d/%s">%s</a></td>',$class,ucfirst($actionpath), $row->$pkey, $actionpath, $title);
            } elsif ($column =~ /^_(.*)$/) {
                my $action = $1;
                $tabletext .= sprintf('<td%s><a href="%d/%s">%s</a></td>', $class, $row->$pkey, $action, ucfirst($action));
            } else {
                $tabletext .= sprintf('<td%s>%s</td>', $class, $row->$column // '');
            }
        }
        $tabletext .= "</tr>\n";
    }
    $tabletext .= '</table>';
    $c->stash->{table} = $tabletext;

    $c->stash->{template} ||= $fu->{template_path}.'/list.tt';
}

sub edit :Chained('object_setup') :PathPart('edit') :Args(0) :FormConfig {
    my ($self, $c) = @_;
    
    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};
    my $object = $c->stash->{object};

    if ($form->submitted_and_valid) {
        my $params = $c->forward('call_subaction',['process_form', $form]) || $form->params;
        delete $params->{$form->indicator};
        delete $params->{$_} foreach @{$fu->{ignores} || []};
        foreach my $param (keys %$params) {
            my $element = $form->get_element({ name => $param });
            next unless $element;
            if ($element->type eq 'Checkbox') {
                next if $params->{$param};
                $params->{$param} = 0;
            } elsif ($element->type eq 'Text') {
                next unless defined $params->{$param} && $params->{$param} eq '';
                $params->{$param} = undef;
            }
        }
        $object->update($params);
        
        $c->forward('call_subaction',['object_updated', $form]);

        $c->flash->{message} ||= "Successfully updated ".$fu->{display_name};
        $c->forward('list_redirect');
    } else {
        $form->model->default_values($object);
        $c->forward('call_subaction',['form_setup', $form]);
    }
    $c->stash->{template} ||= $fu->{template_path}.'/edit.tt';
}

sub create :Chained('base') :PathPart('create') :Args(0) :FormConfig {
    my ($self, $c) = @_;

    my $form = $c->stash->{form};
    my $fu = $c->stash->{fu};

    if ($form->submitted) {
        if ($form->valid) {
            my $obj = $fu->{class}->new_result($c->forward('call_subaction',['defaults', $form]) || $fu->{global_defaults} || {});
            my $params = $c->forward('call_subaction',['process_form', $form]) || $form->params;
            delete $params->{$form->indicator};
            delete $params->{$_} foreach @{$fu->{ignores} || []};
            $obj->$_($params->{$_}) foreach keys %$params;
            $obj->insert;
            $c->stash->{object} = $obj;
            
            $c->forward('call_subaction',['object_updated', $form]);

            $c->flash->{message} ||= "New ".$fu->{display_name}." created";
            $c->forward('list_redirect');
        }
    }
    $c->forward('call_subaction',['form_setup', $form]);
    $c->stash->{template} ||= $fu->{template_path}.'/create.tt';
}

sub delete :Chained('object_setup') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;
    
    my $object = $c->stash->{object};
    my $fu = $c->stash->{fu};

    if ($c->req->param('confirm')) {
        $c->flash->{message} = "Successfully deleted ".$fu->{display_name}.".";
        $object->delete;
        $c->forward('list_redirect');
    }
    $c->stash->{template} ||= $fu->{template_path}.'/delete.tt';
}

sub object_setup :Chained('base') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;

    my $fu = $c->stash->{fu};

    my ($object) = $fu->{search}->search({ 'me.'.$fu->{pkey} => $id })->first;

    unless ($object) {

        $c->flash->{error} = $fu->{name}." does not exist or you do not have permissions for it.";
        $c->forward('list_redirect');
    }
    
    my $column = $fu->{identifying_field};
    $fu->{identity} = $object->$column;

    $c->stash->{object} = $object;
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
    $params{identifying_field} ||= $params{pkey};
    $params{search} = $params{class}->search(
        ($params{global_defaults} || {}),
        {
            %{$params{search_attrs} || {}},
            %{
                $params{sort} 
                || { order_by => { '-asc' => $params{pkey} } } 
            },
        }
    ) unless $params{search};
    unless ($params{template_path}) {
        if ($params{templates} && $params{templates} eq 'custom') {
            my $listpath = $self->action_for('list');
            $listpath =~ s/list$//;
            $params{template_path} = $listpath;
        } else {
            $params{template_path} = 'crudfu';
        }
    }
    my $dist_dir;
    try {
        $dist_dir = dist_dir('Catalyst::Controller::DBIC::CRUDFu')
    }
    catch {
        $dist_dir = '/oofle/perl-lib/share/dist/Catalyst-Controller-DBIC-CRUDFu'
    };
    push(
        @{ $c->view('TT')->include_path }, 
        $dist_dir
    ) unless grep { $_ eq $dist_dir } $c->view('TT')->include_path;
    $c->stash->{fu} = \%params;
}

sub base :Chained('/') :PathPart('objectfu') :CaptureArgs(0) {
    my ($self, $c) = @_;

}

sub index :Chained('base') :Args(0) :PathPart('') {
    my ($self, $c) = @_;
    my $curpath = $c->req->uri;
    $curpath =~ s/\/$//;
    $c->response->redirect("$curpath/list");
    $c->detach;
}

sub call_subaction :Private {
    my ($self, $c, $name, $form) = @_;
    foreach my $sub ($c->action->name."_$name", $name) {
        my $action = $c->get_action($sub,$c->namespace);
        next unless $action;
        return $c->forward($action, [$form]);
    }
    return wantarray ? () : undef;
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
