#!/bin/bash

################################
# Another example testrunner script
################################

#no information gain, All
java -Xmx20000M BOWCreator -A

#no information gain, All, WC
java -Xmx20000M BOWCreator -A -WC

#no information gain, All, Cross Validation = 10
java -Xmx20000M BOWCreator -A -V 10

#no infrormation gain, ALL, WC, Cross Validation = 10
java -Xmx20000M BOWCreator -A -WC -V 10

#information gain, All
java -Xmx20000M BOWCreator -I -A

#information gain, All, WC
java -Xmx20000M BOWCreator -I -A -WC

#information gain, All, Cross Validation = 10
java -Xmx20000M BOWCreator -I -A -V 10

#information gain, All, WC,  Cross Validation = 10
java -Xmx20000M BOWCreator -I -A -WC -V 10

#no inforamtion gain
java -Xmx20000M BOWCreator

#no information gain, WC
java -Xmx20000M BOWCreator -WC

#no information gain, Cross Validation = 10
java -Xmx20000M BOWCreator -V 10

#no information gain, WC, Cross Validation = 10
java -Xmx20000M BOWCreator -WC -V 10

#information gain,
java -Xmx20000M BOWCreator -I

#information gain, WC
java -Xmx20000M BOWCreator -I -WC

#information gain, Cross Validation = 10
java -Xmx20000M BOWCreator -I -V 10

#information gain, WC, Cross Validation = 10
java -Xmx20000M BOWCreator -I -WC -V 10 
