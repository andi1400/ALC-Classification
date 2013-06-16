#!/usr/bin/perl
use strict;
use Data::Dumper;


###########################################
# An example perl script that will perform a batch run of the Java code.#
############################################

#lower threshold for sep tests
system("java -Xmx200000M Classify -I -V 10 -P sep -T " . 1e-3 . " -C SMONBLOMV3");
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java -Xmx200000M Classify -NH -I -V 10 -P sep -T $newTR -C SMONBLOMV3");
}

system("java -Xmx200000M Classify -I -V 10 -P sep -T " . 1e-3 . " -WC -C SMONBLOMV3");
#lower threshold for sep WC tests
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java -Xmx200000M Classify -NH -I -V 10 -P sep -T $newTR -WC -C SMONBLOMV3");
}

#lower threshold for comDQDPMP tests
system("java -Xmx200000M Classify -I -V 10 -P comDQDPMP -T " . 1e-3 . " -C SMONBLOMV3");
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java -Xmx200000M Classify -NH -I -V 10 -P comDQDPMP -T $newTR -C SMONBLOMV3");
}

#lower threshold for comDQDPMP WC tests
system("java -Xmx200000M Classify -I -V 10 -P comDQDPMP -T " . 1e-3 . " -WC -C SMONBLOMV3");
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java -Xmx200000M Classify -NH -I -V 10 -P comDQDPMP -T $newTR -WC -C SMONBLOMV3");
}

#lower threshold for com  tests
system("java -Xmx200000M Classify -I -V 10 -P com -T " . 1e-3 . "  -C SMONBLOMV3");
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java Classify -NH -I -V 10 -P com -T $newTR -C SMONBLOMV3");
}

#lower threshold for com WC tests
system("java -Xmx200000M Classify -I -V 10 -P com -T " . 1e-3 . " -WC -C SMONBLOMV3");
for (my $threshold = 4; $threshold < 9; $threshold += 1) {
	my $newTR = 10 ** (-$threshold);
	system("java Classify -NH -I -V 10 -P com -T $newTR -WC -C SMONBLOMV3");
}


