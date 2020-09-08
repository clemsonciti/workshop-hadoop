#!/bin/bash
echo $1
rm -Rf _site/*
echo ${PWD}
rm -Rf _site
docker run -p 127.0.0.1:4000:4000  -v ${PWD}:/srv/jekyll -it jekyll/jekyll:stable /srv/jekyll/deploy.sh --verbose