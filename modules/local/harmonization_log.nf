process harmonization_log {
    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "ebispot/gwas-sumstats-harmoniser:latest"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 'docker://ebispot/gwas-sumstats-harmoniser:latest' : dockerimg }"
   

    input:
    val chr
    tuple val(GCST), val(mode), path(all_hm), path(qc_result), path(delete_sites), path(count), path(raw_yaml), path(input)
    path(unmapped)

    output:
    tuple val(GCST), path(qc_result), path ("${GCST}.running.log"),  path ("${GCST}.h.tsv.gz-meta.yaml"), env(result), emit: running_result

    shell:
    """
    log_script.sh \
    -r "${params.ref}/homo_sapiens-${chr}.vcf.gz" \
    -i $input \
    -c $count \
    -d $delete_sites \
    -h $all_hm \
    -u $unmapped \
    -o ${GCST}.running.log

    N=\$(awk -v RS='\t' '/hm_code/{print NR; exit}' $qc_result)
    sed 1d $qc_result| awk -F "\t" '{print \$'"\$N"'}' | creat_log.py >> ${GCST}.running.log
    
    result=\$(grep Result ${GCST}.running.log | cut -f2)

    # metadata file

    data_file_name="${GCST}.h.tsv.gz"
    out_yaml="${GCST}.h.tsv.gz-meta.yaml"
    data_file_md5sum=\$(md5sum<${launchDir}/$GCST/final/${GCST}.h.tsv.gz | awk '{print \$1}')
    date_last_modified=\$(date  +"%Y-%m-%d")
    harmonisation_reference=\$(tabix -H "${params.ref}/homo_sapiens-${chr}.vcf.gz" | grep reference | cut -f2 -d '=')

    gwas_metadata.py \
    -i $raw_yaml \
    -o \$out_yaml \
    --dataFileName \$data_file_name \
    --data_file_md5sum \$data_file_md5sum \
    --is_harmonised True \
    --is_sorted True \
    --genome_assembly GRCh38 \
    --coordinate_system 1-based \
    --date_last_modified \$date_last_modified \
    --harmonisation_reference \$harmonisation_reference \
    """
}