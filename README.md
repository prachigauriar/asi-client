# IBM Tivoli Monitoring Agent Service Interface Client

The ASI Client is a simple example of how to use the IBM Tivoli Monitoring (ITM) Agent Service Interface (ASI) to
programmatically get data from an ITM agent. It does not perform much error checking nor does it do anything with
returned data beyond printing it out to the standard output device. However, its code can be built upon to do more
interesting things if needed.


## Requirements 

The ASI client requires the libxml-ruby gem and the included Tabular module. Obviously you need to be able to 
connect to an ITM agent via a network to do anything useful.


# License

All code is licensed under the MIT license. Do with it as you will.
