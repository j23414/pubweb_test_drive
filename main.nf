#! /usr/bin/env nextflow

nextflow.enable.dsl=2

// === define params
params.seqmet_pairs="*_{sequence.fasta, metadata.tsv}"
params.configfile_yaml="*.yaml"

params.docker_image="nextstrain/base:latest"
params.pathogen_giturl="https://github.com/nextstrain/ncov/archive/refs/heads/master.zip"
params.s3deploy=""

// === define processes

process ncov_build {
  input: tuple path(sequence_fasta), path(metadata_fasta), path(build_yaml)
  output: tuple path("auspice"), path("results")
  script:
  """
  #! /usr/bin/env bash

  # Pull ncov, zika or similar pathogen repo
  wget -O master.zip ~{pathogen_giturl}
  INDIR=`unzip -Z1 master.zip | head -n1 | sed 's:/::g'`
  unzip master.zip  
  if [ -n "~{sequence_fasta}" ]
  then
    mv ~{sequence_fasta} $INDIR/.
    mv ~{metadata_tsv} $INDIR/.
  fi
  if [ -n "~{custom_zip}" ]
  then
    # Link custom profile (zipped version)
    cp ~{custom_zip} here_custom.zip
    CUSTOM_DIR=`unzip -Z1 here_custom.zip | head -n1 | sed 's:/::g'`
    unzip here_custom.zip
    cp -r $CUSTOM_DIR/*_profile $INDIR/.
  fi
  # Draft: if passing build file from zip folder
  # BUILDYAML=`ls -1 $CUSTOM_DIR/*.yaml | head -n1`
  # cp $BUILDYAML $INDIR/build_custom.yaml
  
  # Max out the number of threads
  PROC=`nproc`  
  # Run nextstrain
  nextstrain build \
    --cpus $PROC \
    --memory  ~{memory}Gib \
    --native $INDIR ~{"--configfile " + build_yaml} \
    ~{"--config active_builds=" + active_builds}
    
  # Prepare output
  mv $INDIR/auspice .
  zip -r auspice.zip auspice
  
  # For debugging
  mv $INDIR/results .
  cp $INDIR/.snakemake/log/*.log results/.
  zip -r results.zip results
  """
}

// === connect workflow

workflow {
  channel.ofFilePairs(params.seqmet_pairs)
  | combine(channel.ofPath(params.configfile_yaml)
  | ncov_build
  | view
}