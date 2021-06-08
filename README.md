# Kafka Connect Cloudant

[![Build Status](https://travis-ci.org/cloudant-labs/kafka-connect-cloudant.svg?branch=master)](https://travis-ci.org/cloudant-labs/kafka-connect-cloudant)
[![Maven Central](https://img.shields.io/maven-central/v/com.cloudant/kafka-connect-cloudant.svg)](http://search.maven.org/#search|ga|1|g:"com.cloudant"%20AND%20a:"kafka-connect-cloudant")

Kafka Connect Cloudant Connector. This project includes source & sink connectors.

## Release Status

Experimental

## Table of Contents

* Configuration
* Usage

## Configuration

The Cloudant Kafka connector can be configured in standalone or distributed mode according to the [Kafka Connector documentation](http://docs.confluent.io/3.0.1/connect/userguide.html#configuring-connectors).

Make sure to include the following values for either configuration:

Parameter | Value
---:|:---
key.converter|org.apache.kafka.connect.json.JsonConverter
value.converter|org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable|true
value.converter.schemas.enable|true
offset.storage.file.filename|storage
bootstrap.servers|localhost:9092

Assume these settings in a file `connect-standalone.properties` or `connect-distributed.properties`.

### Cloudant as source

To read from a Cloudant database as source and write documents to a Kafka topic, create a source configuration file

`connect-cloudant-source.properties`

with the following parameters:

Parameter | Value | Required | Default value | Description
---:|:---|:---|:---|:---
name|cloudant-source|YES|None|A unique name to identify the connector with.
connector.class|com.ibm.cloudant.kafka.connect.CloudantSourceConnector|YES|None|The connector class name.
topics|\<topic1\>,\<topic2\>,..|YES|None|A list of topics you want messages to be written to.
cloudant.db.url|https://\<account\>.cloudant.com/\<database\>|YES|None|The Cloudant database to read documents from.
cloudant.db.username|\<username\>|YES|None|The Cloudant username to use for authentication.
cloudant.db.password|\<password\>|YES|None|The Cloudant password to use for authentication.
cloudant.db.since|1-g1AAAAETeJzLYWBgYMlgTmGQT0lKzi9..|NO|0|The first change sequence to process from the Cloudant database above. 0 will apply all available document changes.
batch.size|400|NO|1000|The batch size used to bulk read from the Cloudant database.
cloudant.omit.design.docs|false|NO|false| Set to true to omit design documents from the messages produced.
cloudant.value.schema.struct|false|NO|false| _EXPERIMENTAL_ Set to true to generate a `org.apache.kafka.connect.data.Schema.Type.STRUCT` schema and send the Cloudant document payload as a `org.apache.kafka.connect.data.Struct` using the schema instead of the default of a string of the JSON document content when using the Cloudant source connector.
cloudant.value.schema.struct.flatten|false|NO|false| _EXPERIMENTAL_ Set to true to flatten nested arrays and objects from the Cloudant document during struct generation. Only used when cloudant.value.schema.struct is true and allows processing of JSON arrays with mixed element types when using that option.

### Cloudant as sink

To consume messages from a Kafka topic and save as documents into a Cloudant database, create a sink configuration file

`connect-cloudant-sink.properties`

with the following parameters:

Parameter | Value | Required | Default value | Description
---:|:---|:---|:---|:---
name|cloudant-sink|YES|None|A unique name to identify the connector with.
connector.class|com.ibm.cloudant.kafka.connect.CloudantSinkConnector|YES|None|The connector class name.
topics|\<topic1\>,\<topic2\>,..|YES|None|The list of topics you want to consume messages from.
cloudant.db.url|https://\<account\>.cloudant.com/\<database\>|YES|None|The Cloudant database to write documents to.
cloudant.db.username|\<username\>|YES|None|The Cloudant username to use for authentication.
cloudant.db.password|\<password\>|YES|None|The Cloudant password to use for authentication.
tasks.max|5|NO|1|The number of concurrent threads to use for parallel bulk insert into Cloudant.
batch.size|400|NO|1000|The maximum number of documents to commit with a single bulk insert.
replication|false|NO|false|Managed object schema in sink database <br>*true: duplicate objects from source <br>false: adjust objects from source (\_id = [\<topic-name\>\_\<partition\>\_\<offset>\_\<sourceCloudantObjectId\>], kc\_schema = Kafka value schema)*

## Usage

The kafka-cloudant-connect jar is available to download from [Maven Central](http://search.maven.org/#search|ga|1|g:"com.cloudant"%20AND%20a:"kafka-connect-cloudant").

Kafka will use the $CLASSPATH to locate available connectors. Make sure to add the connector library to your $CLASSPATH first.

Connector execution in Kafka is available through scripts in the Kafka install path:

`$kafka_home/bin/connect-standalone.sh` or `$kafka_home/bin/connect-distributed.sh`

Use the appropriate configuration files for standalone or distributed execution with Cloudant as source, as sink, or both.

For example:
- standalone execution with Cloudant as source:

  ```
  $kafka_home/bin/connect-standalone.sh connect-standalone.properties connect-cloudant-source.properties
  ```

- standalone execution with Cloudant as sink:

  ```
  $kafka_home/bin/connect-standalone.sh connect-standalone.properties connect-cloudant-sink.properties
  ```

- standalone execution with multiple configurations, one using Cloudant as source and one using Cloudant as sink:

  ```
  $kafka_home/bin/connect-standalone.sh connect-standalone.properties connect-cloudant-source.properties connect-cloudant-sink.properties
  ```

Any number of connector configurations can be passed to the executing script.

INFO level logging is configured by default to the console. To change log levels or settings, work with

`$kafka_home/config/connect-log4j.properties`

and add log settings like

`log4j.logger.com.ibm.cloudant.kafka=DEBUG, stdout`
