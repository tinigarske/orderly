## ---
## title: "orderly"
## author: "Rich FitzJohn"
## date: "`r Sys.Date()`"
## output: rmarkdown::html_vignette
## vignette: >
##   %\VignetteIndexEntry{orderly}
##   %\VignetteEngine{knitr::rmarkdown}
##   %\VignetteEncoding{UTF-8}
## ---

##+ echo = FALSE, results = "hide"
lang_output <- function(x, lang) {
  writeLines(c(sprintf("```%s", lang), x, "```"))
}
r_output <- function(x) lang_output(x, "r")
yaml_output <- function(x) lang_output(x, "yaml")
plain_output <- function(x) lang_output(x, "plain")
orderly_file <- function(...) {
  system.file(..., package = "orderly", mustWork = TRUE)
}

path <- orderly:::prepare_orderly_example("example")
path_example <- file.path(path, "src", "example")
orderly:::orderly_default_config_set(orderly:::orderly_config(path))
orderly::orderly_log_start()

tree <- function(path, header = path) {
  paste1 <- function(a, b) {
    paste(rep_len(a, length(b)), b)
  }
  indent <- function(x, files) {
    paste0(if (files) "| " else "  ", x)
  }
  is_directory <- function(x) {
    unname(file.info(x)[, "isdir"])
  }
  sort_files <- function(x) {
    i <- grepl("^[A-Z]", x)
    c(x[i], x[!i])
  }
  prefix_file <- "|--="
  prefix_dir  <- "|-+="

  files <- sort_files(dir(path))
  files_full <- file.path(path, files)
  isdir <- is_directory(files_full)

  ret <- as.list(c(paste1(prefix_dir, files[isdir]),
                   paste1(prefix_file, files[!isdir])))
  files_full <- c(files_full[isdir], files_full[!isdir])
  isdir <- c(isdir[isdir], isdir[!isdir])

  n <- length(ret)
  if (n > 0) {
    ret[[n]] <- sub("|", "\\", ret[[n]], fixed = TRUE)
    tmp <- lapply(which(isdir), function(i)
      c(ret[[i]], indent(tree(files_full[[i]], NULL), !all(isdir))))
    ret[isdir] <- tmp
  }

  c(header, unlist(ret))
}

## ## The problem

## Suppose that we have an SQL database that is used for a series of
## "reports" (e.g., graphs, knitr documents, data exports).  These
## reports might change because:
##
## * the data in the SQL database changes
## * we apply the reporting scripts to different subsets of the data
## * the code that we use to generate the scripts changes
##
## (among other more pathalogical reasons such as the packages that
## we're using changing behaviour, etc)
##
## We would like to be able to generate reports easily from the
## database and later on compare two reports and easily be able to
## determine _why_ two versions of a report differ - particularly with
## respect to the above criteria.  We'd also like to be able to get
## the original data that was used to create the reports (even if the
## SQL database has moved on) and the original scripts that were used
## to create the reports.

## ## Example

## The `orderly.yml` to describe the creation of a report might look like:
##+ results = "asis", echo = FALSE
yaml_output(readLines(file.path(path_example, "orderly.yml")))

## Hopefully this is somewhat self explanatory:

## * `data` is the data sets to pull from the database; it is a named
##   list with one or more elements.  Each element is a SQL query
##   indicating the required data.  You can use placeholders like
##   `?cyl` in the above example to stand in for *parameters* that
##   will be passed through to the report.
##
## * `parameters` is a list of parameters used to query the SQL
##   database.  Note the that only the *names* of the parameters are
##   provided here - the values will be provided when the report is
##   run.
##
## * `script.R` is the R script that will be run to do the actual work
##   of the report - any R code can be used here.
##
## * `artefacts` is a list of "artefacts" that are created by the
##   `script`; these are *files* that contain the report itself.
##   There can be more than one artefact (there are two here).  Under
##   each filename, list the `format` (`"staticgraph"`,
##   `"interactivegraph"`, `"data"` for now) and a free-text
##   description.
##
## There are other optional fields that can be added to the yaml (and
## `parameters` is optional) but this is the core.  The file
## `script.R` for this report contains

##+ results = "asis", echo = FALSE
yaml_output(readLines(file.path(path_example, "script.R")))

## The important thing here is that the report references the variable
## `cars` and `cyl` even though it does not create them!  It must
## produce the files that are mentioed in `artefacts`
## (`disp_vs_wt.png` and `distribution.png`).  The R code can be as
## long and as short as needed and can use whatever packages it needs.
## `orderly` does not do anything with the script apart from run it so
## it can be formatted however (there are no magic comments, etc).
## There is no restrictions on what can be done except:
##
## * don't try to directly access the database
## * the script must create the artefacts listed in `orderly.yml`

## There is some more infrastructure that needs to be put in place
## around this; how does the report access the SQL database?  And
## where to the generated reports reside?
##+ results = "asis", echo = FALSE
plain_output(tree(path, "<root>"))

## The directories will be discussed in further detail below but we have:

## * `archive` - completed reports.  These are reports that we might
##   distribute to people or synchronise with a central point.
## * `data` - copies of the data used to create reports, stored so
##   that reports can be rerun later.
## * `draft` - draft reports.  Every run of a report will create a new
##   directory in here, but relatively few of these will be "final"
##   reports.  So reports exist here before being copied to `archive`.
## * `src` - the report *sources*; the files `orderly.yml` and
##   `script.R` are the files from above.
## * `orderly_config.yml` - this is the global configuration
## * `source.sqlite` - this is the example database used here

## The global configuration looks like:
##+ results = "asis", echo = FALSE
yaml_output(readLines(file.path(path, "orderly_config.yml")))

## This defines the field `source`, which describes the database that
## we pull results from (the database that the report queries are run
## against).  This contains a field `driver` which must declare a
## DBI-compatible driver (realistically this is going to be
## `RSQLite::SQLite` for a local SQLite database and
## `RPostgres::Posgres` for accessing a postgres database), and then
## any arguments to be passed through to `DBI::dbConnect` along with
## the driver.  For SQLite this is just going to be `dbname` but for
## postgres this will include `host`, `port`, `user`, `dbname` and
## `password`.  For example:

## ```yaml
## source:
##   driver: RSQLite::SQLite
##   host: dbhost
##   port: 5432
##   user: myusername
##   password: s3cret
##   dbname: mydb
## ```

## In order to run anything (as below) the working directory must be
## somewhere above the root.  `orderly` will look in directories up
## towards the filesystem root for a file `orderly_config.yml` to
## determine the root.  For Rstudio users, creating an .Rproj file
## here is probably a good idea.

## ## Running a report

## Reports are run by *name*.  In the above configuration the report
## is called `example` because it is in the directory `src/example`.
## A list of report names can be returned by running
orderly::orderly_list()

## If the report requires parameters then these must be passed through
## too; in the above case the report takes the parameter `cyl` which
## must be passed through as a named list.  So we might run this
## report as
##+ collapse = TRUE
id <- orderly::orderly_run("example", list(cyl = 4))

### need this for later:
##+ echo = FALSE, results = "hide"
h <- sub("\\.rds$", "", dir(file.path(path, "data", "rds")))

## The return value is the id of the report (also printed on the
## second line of log output) and is always in the format
## `YYYYMMDD-HHMMSS-abcdef01` where the last 8 characters are a hex
## digits (i.e., 4 random bytes).  This means reports will
## automatically sort nicely but we'll have some collision resistance.
id

## Having run the report, the directory layout now looks like:
##+ results = "asis", echo = FALSE
plain_output(tree(path, "<root>"))

## Within `drafts`, the directory ``r file.path("example", id)`` has been
## created which contains the result of running the report.  In here
## there are the files:
##
## * `orderly.yml`: this is an exact copy of the input file
## * `script.R`: this is an exact copy of the script used for the analysis
## * `disp_vs_wt.png` and `distribution.png`: the artefacts created by
##    the report
## * `orderly_run.yml`: this is metadata about the run (hash of input
##   files, of the data used, and of the output etc)
## * `orderly_run.rds`: version information on all R packages used (in
##   R's rds format as I don't think we need this from anything but R)

## Every time a report is run it will create a new directory at this
## level with a new id.  Running the report again now might create the
## directory ``r file.path("example", orderly:::new_report_id())``

## Note that there are other files created;
##
## * ``r file.path("data", "csv", paste0(h, ".csv"))``
## * ``r file.path("data", "rds", paste0(h, ".rds"))``
##
## These are a copy of the data as extracted from the database and
## used in the report.  The filenames are derived from a hash of the
## contents of the file, so if two reports use the same data then only
## one copy will be saved (this is quite likely if the upstream data
## and the query have not changed).  Two copies are saved - the rds
## version is faster to read and write, usually smaller, and is
## exactly the data as used, while the csv version is more easily read
## by other applications.

## You can see the list of draft reports like so:
orderly::orderly_list_drafts()

## Once you're happy with a report, then "commit" it with
##+ collapse = TRUE
orderly::orderly_commit(id)

## **THIS WILL CHANGE A LITTLE I THINK** - but mostly in how the index
## is built and how we might synchronise reports across people and
## machines.

## After this step our directory structure looks like:
##+ results = "asis", echo = FALSE
plain_output(tree(path, "<root>"))

## Which looks very like the previous, but files have been moved from
## being within `draft` to being within `archive`.  The other
## difference is that the index `orderly.sqlite` has been created.

## ## Developing a report

## First, create a directory within `src`.  The name is important and
## should not contain spaces (nor should it change as this will change
## the key report id and you'll lose a chain of history).
dir.create(file.path(path, "src", "new"))
