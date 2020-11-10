#!/bin/sh
#
# --------------------------------------------------------------------------- #
# Script to copy data for Capacity Usage report from caxrpt home to WHQ       #
# caxrpt home folders for BI to Snowflake.                                    #
# Stewart McKenna. 2020/09/18                                                 #
# --------------------------------------------------------------------------- #

  cd /home/caxrpt/reportdata
  cd disk_usage_user_PBO
  rsync -avz punlx07:/home/caxrpt/reportdata/disk_usage_user/* .
  cd ..
  cd disk_usage_user_EHQ
  rsync -avz fralx07:/home/caxrpt/reportdata/disk_usage_user/* .
