#!/bin/bash

pytest

cd tests/testthat
Rscript -e "testthat::test_local()"
