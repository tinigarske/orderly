# orderly

[![Project Status: Concept – Minimal or no implementation has been done yet, or the repository is only intended to be a limited example, demo, or proof-of-concept.](http://www.repostatus.org/badges/latest/concept.svg)](http://www.repostatus.org/#concept)
[![Build Status](https://travis-ci.org/vimc/orderly.svg?branch=master)](https://travis-ci.org/vimc/orderly)
[![codecov.io](https://codecov.io/github/vimc/orderly/coverage.svg?branch=master)](https://codecov.io/github/vimc/orderly?branch=master)

> 1. an attendant in a hospital responsible for the non-medical care of patients and the maintenance of order and cleanliness.
> 2. a soldier who carries orders or performs minor tasks for an officer.

## Use case

A research group with a potentially changing SQL database who want to create reports (knitr documents, csv exports, graphics) from the database but who want to be able to trace back from a report to metadata about what created it.

## The process

* (optional) Establish temporary SQL views in the database
* Run one or more queries against the database and extract a set of data
* Run an R script against the exported tables, producing one or more report artefacts
* Save a set of metadata
* Archive the exported data set
