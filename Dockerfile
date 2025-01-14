# This file is part of xrootdpyfs
# Copyright (C) 2015-2020 CERN.
#
# xrootdpyfs is free software; you can redistribute it and/or modify it under
# the terms of the Revised BSD License; see LICENSE file for more details.
#
# Dockerfile for running XRootDPyFS tests.
#
# Usage:
#   docker build -t xrootd . && docker run -h xrootdpyfs -it xrootd

FROM centos:7

RUN yum install -y git wget epel-release
RUN yum group install -y "Development Tools"

# Install and set python3.6 as default
RUN yum install -y centos-release-scl && \
    yum install -y rh-python36
RUN echo '#!/bin/bash' >> /etc/profile.d/enablepython36.sh && \
    echo '. scl_source enable rh-python36' >> /etc/profile.d/enablepython36.sh
ENV BASH_ENV=/etc/profile.d/enablepython36.sh

RUN chmod -R g=u /etc/profile.d/enablepython36.sh /opt/rh/rh-python36 && \
    chgrp -R 0 /etc/profile.d/enablepython36.sh /opt/rh/rh-python36
SHELL ["/bin/bash", "-c"]

RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum install -y devtoolset-7
RUN scl enable devtoolset-7 bash

# Install xrootd
# cmake needed for xrootd<5.x, cmake3 for xrootd>=4.12.7
ARG xrootd_version=""
ARG cmake="cmake3"
RUN yum-config-manager --add-repo https://xrootd.slac.stanford.edu/binaries/xrootd-stable-slc7.repo
RUN if [ ! -z "$xrootd_version" ] ; then XROOTD_V="-$xrootd_version" ; else XROOTD_V="" ; fi && \
    echo "Will install xrootd version: $XROOTD_V (latest if empty)" && \
    yum --setopt=obsoletes=0 install -y "$cmake" \
                                        gcc-c++ \
                                        zlib-devel \
                                        openssl-devel \
                                        libuuid-devel \
                                        python3-devel \
                                        xrootd"$XROOTD_V"

# Install some prerequisites ahead of `setup.py` in order to take advantage of
# the docker build cache:
RUN pip install --upgrade pip setuptools wheel

# Install Python xrootd
# Ensure that installed version of xrootd Python client is the same as the RPM package
RUN rpm --queryformat "%{VERSION}" -q xrootd
RUN XROOTD_V=`rpm --queryformat "%{VERSION}" -q xrootd` && \
    echo "RPM xrootd version installed: $XROOTD_V" && \
    pip install xrootd=="$XROOTD_V"

WORKDIR /code
COPY . /code

RUN pip install -e '.[tests]'
RUN pip freeze

RUN adduser --uid 1001 xrootdpyfs
RUN chown -R xrootdpyfs:xrootdpyfs /code
RUN chmod a+x /code/run-docker.sh
RUN chmod a+x /code/run-tests.sh

USER xrootdpyfs

RUN mkdir /tmp/xrootdpyfs && echo "Hello XRootD!" >> /tmp/xrootdpyfs/test.txt

# Print xrootd version
RUN XROOTD_V=`xrootd -v` && echo "xrootd version when running it: $XROOTD_V"

CMD ["bash", "/code/run-docker.sh"]
