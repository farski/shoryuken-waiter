# Shoryuken::Waiter

[![Gem Version](http://img.shields.io/gem/v/shoryuken-waiter.svg)](https://rubygems.org/gems/shoryuken-waiter)
[![Dependency Status](https://gemnasium.com/farski/shoryuken-waiter.svg)](https://gemnasium.com/farski/shoryuken-waiter)
[![Build Status](https://travis-ci.org/farski/shoryuken-waiter.svg)](https://travis-ci.org/farski/shoryuken-waiter)
[![Code Climate](https://codeclimate.com/github/farski/shoryuken-waiter/badges/gpa.svg)](https://codeclimate.com/github/farski/shoryuken-waiter)
[![Coverage Status](https://coveralls.io/repos/farski/shoryuken-waiter/badge.svg?branch=master)](https://coveralls.io/r/farski/shoryuken-waiter?branch=master)

Based heavily on [`shoryuken-later`](https://github.com/joekhoobyar/shoryuken-later).

Version 0.x is tightly coupled Rails and Shoryuken SQS queues. 1.x should add support for Shoryuken workers (currently only Active Job is supported), and more configurable DynamoDB tables.

Waiter runs whenever Shoryuken is running. It watches DynamoDB tables that correspond with every Shoryuken queue defined, _if_ that DynamoDB table exists when Waiter starts up. If there are queues in Shoryuken called `queue_one` and `queue_two`, Waiter will look for `queue_one_waiter` and `queue_two_waiter` tables. It will silently ignore any missing tables.

When a job is scheduled with a delay of over 15 minutes, the Active Job adpater will store a record of the job (the SQS message that Shoryuken would have queued) in the table that corresponds to the queue the job would have been placed in.

### Query

To efficiently query tables for items that contain jobs ready to be handed back to SQS, there must be a common hash key across all items. This key is effectively meaningless in the implementation, and is not returned with the items. A job's `job_id` is used as the item's range key, to ensure each item's primary key is unique.

A local secondary index is used to support querying based on the time jobs are scheduled. An LSI that shares hash keys with the table and uses the `perform_at` as the range key makes this possible. Index primary keys do not need to be unique, which prevents any issues where multiple jobs have the same `perform_at` value.
