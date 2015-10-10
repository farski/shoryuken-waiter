# Shoryuken::Waiter

[![Gem Version](http://img.shields.io/gem/v/shoryuken-waiter.svg)](https://rubygems.org/gems/shoryuken-waiter)
[![Dependency Status](https://gemnasium.com/farski/shoryuken-waiter.svg)](https://gemnasium.com/farski/shoryuken-waiter)
[![Build Status](https://travis-ci.org/farski/shoryuken-waiter.svg)](https://travis-ci.org/farski/shoryuken-waiter)
[![Code Climate](https://codeclimate.com/github/farski/shoryuken-waiter/badges/gpa.svg)](https://codeclimate.com/github/farski/shoryuken-waiter)
[![Coverage Status](https://coveralls.io/repos/farski/shoryuken-waiter/badge.svg?branch=master&service=github)](https://coveralls.io/github/farski/shoryuken-waiter?branch=master)

Based heavily on the concept of [`shoryuken-later`](https://github.com/joekhoobyar/shoryuken-later), `Shoryuken::Waiter` allows jobs to be scheduled greater that 15 minutes into the future when using [Shoryuken](https://github.com/phstc/shoryuken).

_**Notice:** Version 0.x is tightly coupled Rails and Shoryuken SQS queues. 1.x should add support for Shoryuken workers (currently only Active Job is supported), and more configurable DynamoDB tables._

## Usage

### Integration with ActiveJob

Because **[SQS](https://aws.amazon.com/sqs/)** only allows messages to be [delayed up to 15 minutes](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessage.html), the [`Active Job`](http://guides.rubyonrails.org/active_job_basics.html) adapter that ships with `Shoryuken` does not allow jobs to be scheduled further than 15 minutes out. `Shoryuken::Waiter` provides a replacement adapter that wraps the `Shoryuken` adapter, and allows for jobs to be scheduled arbitrarily far into the future.
```
# config/application.rb
config.active_job.queue_adapter = :shoryuken_waiter
```

If a job is created with a delay of more than 15 minutes, **and** `Shoryuken::Waiter` finds a **[DynamoDB](https://aws.amazon.com/dynamodb/)** table whose name matches the name of the queue for which the job was intended, the properties of the job are captured to that table, allowing it to be rescheduled later on. If a matching table can't be found **or** the job's is 15 minutes or less the native `Shoryuken` adapters handles it.

### The schedule poller

There is no separate poller process that is run to watch for scheduled jobs. Whenever the `Shoryuken` message processor starts up, a Celluloid supervisor maintains a single `Shoryuken::Waiter::Querier` that polls **DynamoDB** for jobs. The poller shuts down when `Shoryuken` stops.

The frequency that tables are queried for scheduleable jobs is `5.minutes` by default. It can be customized by setting the `delay` property in the `Shoryuken` configuration.

```
# config/shoryuken.yml
waiter:
  delay: 30 # seconds
```

### Queues & Tables

When `Shoryuken::Waiter` loads it tries to find a **DynamoDB** table for each **SQS** `Shoryuken` queue that is configured. When a table with a matching name can't be found, `Shoryuken::Waiter` will not poll for jobs intended for that queue, and creating jobs intended for that queue is handled by the the `Shoryuken` `Active Job` adapter.

_**Note:** There is no technical reason that each queue needs it's own table. It would be more cost effective to put all jobs into a single table, so that may be a change that is made in the future._

#### Creating DynamoDB Tables

Tables being used with `Shoryuken::Waiter` must be created with certain properties to work correctly.

* **Table name**: The name of the table must match the name of an **SQS** queue registered with `Shoryuken`
* **Primary key**: The `item key` must be a `String` with the value `scheduler`, and the `sort key` must be a `String` with the value `job_id`
* **Secondary index**: An index (generally a *Local Secondary Index*) must be added to the table. The `item key` of the index's **primary key** must be a `String` with the value `scheduler`, and the `sort key` of the **primary key** must be a `Number` with the value `perform_at`. The **index name** must be `scheduler-perform_at-index`. **Projected attributes** generally can be set to `all`.

Other properties of the table, such as the **provisioned capacity** will be application dependent.

## Internals

When a job is scheduled normally `Shoryuken`, the message is sent to **SQS** with four properties `queue_url`, `message_body`, `delay_seconds`, and `message_attributes`.

When the job must be delayed, `Shoryuken::Waiter` captures enough information to recreate an identical **SQS** message later on. The `message_body` and `message_attributes` are stored unaltered. `delay_seconds` is tranformed into a timestamp, relative to when the job was created, which can be used to query items from a **DynamoDB** table. The message's `queue_url` is discarded, since it can be recreated from the job's queue name, which is already captured as part of the `message_body`.

### Query

After a job is delayed and stored in a **DynamoDB** table, it must be retrieved at the appropriate time, and sent to **SQS** like was originally intended.

The poller needs a way of efficiently finding jobs in tables, and the **DynamoDB** API provides the `query` operation for that purpose.

The `query` operation can either search based on just a **hash key**, or a **hash key** and a **range key**. `Shoryuken::Waiter` is looking for all jobs that are scheduled before a certain point in time (15 minutes from the time of the query). It's only possible to make comparison queries with a **range key**, so using just a hash key would not work. Since the hash key is required for all query operations, but there is no meaningful key in this case, it's value can be arbitrary, as long as it is consistent.

Using the job's timestamp as the **range key** would be reasonable, except that more than one job may be scheduled for the same time. Since all items are being given the same **hash key**, identical **range keys** would violate the primary key uniqueness constraint. Instead of using a value from the table's primary key for the comparison query, a **secondary index** can be added to the table, which also allows for **range keys** to be queried.

The **range key** of the table's primary key simply needs to provide uniqueness, so the job's unique ID can be used for that. The **hash key** of the secondary index must match the hash key of the table, so it will also be the arbitrary value that is selected. The **range key** will be the `perform_at` timestamp, and since secondary indexes do not require primary keys to be unique, there is no risk of collision between jobs with the same timestamp.

A query can now be performed to find any item in the table with a given **hash key** (the arbitrary value shared by all items in the table) and a **range key** that only returns jobs scheduled no later than 15 minutes from now.

If the query returns any items, they must be turned back into **SQS** messages and sent to their intended queue. The stored values are pulled back out of the item, and transformed if necessary (e.g. turning `perform_at` back to `delay_seconds`).

The query returns sets of items, and **SQS** can be sent sets of messages (at most 10). The batches of items are processed into batches of messages, which get sent back to `Shoryuken`, and ultimately to **SQS**.
