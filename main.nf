#! /usr/bin/env nextflow

nextflow.enable.dsl=2

// === define processes

process ncov_build {
  input: tuple path(sequence_fasta), path(metadata_fasta), path(build_yaml)
  output: tuple path("auspice"), path("results")
  script:
  """
  #! /usr/bin/env bash
  # Max out the number of threads
  PROC=`nproc` 
  MEM=48

  # Pull ncov, zika or similar pathogen repo
  wget -O master.zip ${env.pathogen_giturl}
  INDIR=`unzip -Z1 master.zip | head -n1 | sed 's:/::g'`
  unzip master.zip  

  if [ -n "${sequence_fasta}" ]
  then
    mv ${sequence_fasta} \$INDIR/.
    mv ${metadata_tsv} \$INDIR/.
  fi

  # Run nextstrain
  # todo: deal with optionals in nextflow
  # todo: get memory size
  nextstrain build \
    --cpus \$PROC \
    --memory  \${MEM}Gib \
    --native \$INDIR ~{"--configfile " + build_yaml}
    
  # Prepare output
  mv \$INDIR/auspice .
  
  # For debugging
  mv \$INDIR/results .
  cp \$INDIR/.snakemake/log/*.log results/.
  """
}

// === connect workflow

workflow {
  // Check if params do not exist
  // if ("${params.input}" == "false"){
  //   error "Error: User must provide a value for the --input parameter"
  // }

  channel.ofFilePairs(params.seqmet_pairs, checkIfExists:true)
  | combine(channel.ofPath(params.configfile_yaml, checkIfExists:true)
  | ifEmpty { error "Missing inputs for ${params.seqmet_pairs} or ${params.configfile_yaml}"}
  | ncov_build
  | view
}