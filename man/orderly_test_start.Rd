% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/recipe_run.R
\name{orderly_test_start}
\alias{orderly_test_start}
\alias{orderly_test_end}
\alias{orderly_test_restart}
\title{Prepare a directory for orderly to use}
\usage{
orderly_test_start(name, parameters = NULL, envir = .GlobalEnv,
  config = NULL, locate = TRUE)

orderly_test_end(cleanup = FALSE)

orderly_test_restart(cleanup = TRUE)
}
\arguments{
\item{name}{Name of the report to run (see
\code{\link{orderly_list}}).}

\item{parameters}{Parameters passed to the report}

\item{envir}{The parent of environment to evalute the report in;
by default a new environment will be made with the global
environment as the parent.  For \code{orderly_data}, this may be
\code{list()} in which case a list will be returned (rather than
an environment).}

\item{config}{An orderly configuration, or the path to one (or
\code{NULL} to locate one if \code{locate} is \code{TRUE}).}

\item{locate}{Logical, indicating if the configuration should be
searched for.  If \code{TRUE} and \code{config} is not given,
then orderly looks in the working directory and up through its
parents until it finds an \code{orderly_config.yml} file.}

\item{cleanup}{Delete testing directory on exit?  If \code{FALSE}
then you will probably want to use \code{\link{orderly_cleanup}}
later to delete the test directory.  Note that it is not
possible to commit the results of an orderly test run}
}
\description{
For interactive testing of orderly code
}
