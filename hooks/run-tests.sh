#!/bin/bash

# R tests
cd tests/testthat
Rscript -e "testthat::test_local()"

# python tests
cd ../..
coverage run -m pytest
coverage report -m
