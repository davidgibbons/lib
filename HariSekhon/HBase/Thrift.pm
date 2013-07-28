#
#  Author: Hari Sekhon
#  Date: 2013-07-28 23:56:03 +0100 (Sun, 28 Jul 2013)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#  

# Split off from my check_hbase_table.pl Nagios Plugin

package HariSekhon::HBase::Thrift;

$VERSION = "0.1";

use strict;
use warnings;

BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/../..";
}
use HariSekhonUtils;
use Thrift;
use Thrift::Socket;
use Thrift::BinaryProtocol;
use Thrift::BufferedTransport;

use Exporter;
our @ISA = qw(Exporter);

our @EXPORT = ( qw(
                    connect_hbase_thrift
                )
);
our @EXPORT_OK = ( @EXPORT );

# using custom try/catch from my HariSekhonUtils as it's necessary to disable the custom die handler for this to work

sub connect_hbase_thrift($$){
    my $host = shift;
    my $port = shift;
    my $client;
    my $protocol;
    my $socket;
    my $transport;
    try {
        $socket    = new Thrift::Socket($host, $port);
    };
    catch_quit "failed to connect to Thrift server at '$host:$port'";
    try {
        $transport = new Thrift::BufferedTransport($socket,1024,1024);
    };
    catch_quit "failed to initiate Thrift Buffered Transport";
    try {
        $protocol  = new Thrift::BinaryProtocol($transport);
    };
    catch_quit "failed to initiate Thrift Binary Protocol";
    try {
        $client    = Hbase::HbaseClient->new($protocol);
    };
    catch_quit "failed to initiate HBase Thrift Client";

    $status = "OK";

    try {
        $transport->open();
    };
    catch_quit "failed to open Thrift transport to $host:$port";

    return $client;
}

1;