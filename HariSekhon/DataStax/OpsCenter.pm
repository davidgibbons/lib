#
#  Author: Hari Sekhon
#  Date: 2014-09-13 15:44:47 +0100 (Sat, 13 Sep 2014)
#
#  https://github.com/harisekhon
#
#  License: see accompanying Hari Sekhon LICENSE file
#  

package HariSekhon::DataStax::OpsCenter;

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/..";
}
use HariSekhonUtils;
use Carp;
use Data::Dumper;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT = ( qw (
                    $cluster
                    $keyspace
                    $list_clusters
                    $list_keyspaces
                    %clusteroption
                    %keyspaceoption
                    curl_opscenter
                    curl_opscenter_err_handler
                    list_clusters
                    list_keyspaces
                    validate_cluster
                    validate_keyspace
                )
);
our @EXPORT_OK = ( @EXPORT );

set_port_default(8888);

env_creds("DataStax OpsCenter");

our $cluster;
our $keyspace;
our $list_clusters;
our $list_keyspaces;

env_vars(["DATASTAX_OPSCENTER_CLUSTER",  "CLUSTER"],  \$cluster);
env_vars(["DATASTAX_OPSCENTER_KEYSPACE", "KEYSPACE"], \$keyspace);

our %clusteroption = (
    "C|cluster=s"    =>  [ \$cluster,        "Cluster as named in DataStax OpsCenter (\$DATASTAX_OPSCENTER_CLUSTER, \$CLUSTER). See --list-clusters" ],
    "list-clusters"  =>  [ \$list_clusters,  "List clusters managed by DataStax OpsCenter" ],
);
our %keyspaceoption = (
    "K|keyspace=s"   =>  [ \$keyspace,       "KeySpace to check (\$DATASTAX_OPSCENTER_KEYSPACE, \$KEYSPACE). See --list-keyspaces" ],
    "list-keyspaces" =>  [ \$list_keyspaces, "List keyspaces in given Cassandra cluster managed by DataStax OpsCenter. Requires --cluster" ],
);

splice @usage_order, 6, 0, qw/cluster keyspace list-clusters list-keyspaces/;

sub curl_opscenter_err_handler($){
    my $response = shift;
    my $content  = $response->content;
    my $json;
    my $additional_information = "";
    unless($response->code eq "200"){
        my $additional_information = "";
        my $json;
        if($json = isJson($content)){
            if(defined($json->{"status"})){
                $additional_information .= ". Status: " . $json->{"status"};
            }
            if(defined($json->{"reason"})){
                $additional_information .= ". Reason: " . $json->{"reason"};
            } elsif(defined($json->{"message"})){
                $additional_information .= ". Message: " . $json->{"message"};
                if($json->{"message"} eq "Resource not found."){
                    $additional_information = ". Message: keyspace not found - wrong keyspace specified? (case sensitive)";
                }
            }
        }
        quit("CRITICAL", $response->code . " " . $response->message . $additional_information);
    }
    unless($content){
        quit("CRITICAL", "blank content returned from DataStax OpsCenter");
    }
}

sub curl_opscenter($;$){
    my $path = shift;
    my $ssl  = shift;
    my $http = "http";
    $http .= "s" if $ssl;
    ($host and $port and $user and $password) or code_error "host/port/user/password not set before calling curl_opscenter()";
    $path =~ s/^\///g;
    $json = curl_json "$http://$host:$port/$path", "DataStax OpsCenter", $user, $password, \&curl_opscenter_err_handler;
}

sub list_clusters(){
    if($list_clusters){
        $json = curl_opscenter "cluster-configs";
        vlog3 Dumper($json);
        print "Clusters managed by DataStax OpsCenter:\n\n";
        foreach(sort keys %{$json}){
            print "$_\n";
        }
        exit $ERRORS{"UNKNOWN"};
    }
}

sub list_keyspaces(){
    if($list_keyspaces){
        $json = curl_opscenter "$cluster/keyspaces";
        vlog3 Dumper($json);
        print "Keyspaces in cluster '$cluster':\n\n";
        foreach(sort keys %{$json}){
            print "$_\n";
        }
        exit $ERRORS{"UNKNOWN"};
    }
}

sub validate_cluster(){
    unless($list_clusters){
        $cluster or usage "must specify cluster, use --list-clusters to show clusters managed by DataStax OpsCenter";
        $cluster = validate_alnum($cluster, "cluster name");
    }
}

sub validate_keyspace(){
    unless($list_clusters or $list_keyspaces){
        $keyspace or usage "must specify keyspace, use --list-keyspaces to show keyspaces managed by Cassandra cluster '$cluster'";
        $keyspace = validate_alnum($keyspace, "keyspace name");
    }
}

1;
