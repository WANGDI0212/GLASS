## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Extract and sort split reads
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule extractsplitter:
    input:
        "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam"
    output:
        unsorted = temp("results/lumpy/split/{aliquot_id}.realn.mdup.bqsr.splitters.unsorted.bam"),
        sorted = "results/lumpy/split/{aliquot_id}.realn.mdup.bqsr.splitters.sorted.bam"
    params:
        prefix = "results/lumpy/split/{aliquot_id}",
        mem = CLUSTER_META["extractsplitter"]["mem"]
    threads:
        CLUSTER_META["extractsplitter"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/extractsplitter/{aliquot_id}.log"
    benchmark:
        "benchmarks/extractsplitter/{aliquot_id}.txt"
    message:
        "Extracting and sorting split reads\n"
        "Sample: {wildcards.aliquot_id}"
    shell:
        "samtools view -h {input} | \
            extractSplitReads_BwaMem -i stdin | \
            samtools view -Sb - \
            -o {output.unsorted} \
            > {log} 2>&1;"
        "samtools sort \
            -o {output.sorted} \
            -O bam \
            -T {params.prefix} \
            {output.unsorted} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Extract and sort discordant reads
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule extractdiscordant:
    input:
        "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam"
    output:
        unsorted = temp("results/lumpy/discordant/{aliquot_id}.realn.mdup.bqsr.discordant.unsorted.bam"),
        sorted = "results/lumpy/discordant/{aliquot_id}.realn.mdup.bqsr.discordant.sorted.bam"
    params:
        prefix = "results/lumpy/discordant/{aliquot_id}",
        mem = CLUSTER_META["extractdiscordant"]["mem"]
    threads:
        CLUSTER_META["extractdiscordant"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/extractdiscordant/{aliquot_id}.log"
    benchmark:
        "benchmarks/extractdiscordant/{aliquot_id}.txt"
    message:
        "Extracting and sorting discordant reads\n"
        "Sample: {wildcards.aliquot_id}"
    shell:
        "samtools view -b -F 1294 {input} \
            -o {output.unsorted} \
            > {log} 2>&1;"
        "samtools sort \
            -o {output.sorted} \
            -O bam \
            -T {params.prefix} \
            {output.unsorted} \
            > {log} 2>&1"


## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## CNVnator to BEDPE
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule cnvnator_to_bedpe:
    input:
        "results/cnvnator/call/{aliquot_id}.call.tsv"
    output:
        del_o = temp("results/lumpy/cnvbedpe/{aliquot_id}.del.bedpe"),
        dup_o = temp("results/lumpy/cnvbedpe/{aliquot_id}.dup.bedpe"),
        merged = "results/lumpy/cnvbedpe/{aliquot_id}.merged.bedpe"
    params:
        mem = CLUSTER_META["cnvnator_to_bedpe"]["mem"]
    threads:
        CLUSTER_META["cnvnator_to_bedpe"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/cnvbedpe/{aliquot_id}.log"
    benchmark:
        "benchmarks/lumpy/cnvbedpe/{aliquot_id}.txt"
    message:
        "CNVnator to BEDPE\n"
        "Sample: {wildcards.aliquot_id}"
    shell:
        "cnvanator_to_bedpes.py \
            -c {input} \
            --del_o {output.del_o} \
            --dup_o {output.dup_o} \
            -b {config[cnvnator_binsize]} \
            > {log} 2>&1; "
        "cat {output.del_o} {output.dup_o} \
            2>> {log} 1> {output.merged}"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## LUMPY
## Added HEXDUMP defintion because it was undefined for some reason
## Added gatk UpdateVCFSequenceDictionary because bcftools index requires it
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule lumpy_call:
    input:
        tumor = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        normal = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]),
        discordant_tumor = lambda wildcards: "results/lumpy/discordant/{aliquot_id}.realn.mdup.bqsr.discordant.sorted.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        discordant_normal = lambda wildcards: "results/lumpy/discordant/{aliquot_id}.realn.mdup.bqsr.discordant.sorted.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]),
        split_tumor = lambda wildcards: "results/lumpy/split/{aliquot_id}.realn.mdup.bqsr.splitters.sorted.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        split_normal = lambda wildcards: "results/lumpy/split/{aliquot_id}.realn.mdup.bqsr.splitters.sorted.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]),
        bedpe_tumor = lambda wildcards: "results/lumpy/cnvbedpe/{aliquot_id}.merged.bedpe".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        bedpe_normal = lambda wildcards: "results/lumpy/cnvbedpe/{aliquot_id}.merged.bedpe".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"])
    output:
        tmp = temp("results/lumpy/call/{pair_id}.vcf"),
        vcf = "results/lumpy/call/{pair_id}.dict.vcf"
    params:
        mem = CLUSTER_META["lumpy_call"]["mem"],
        tumor_SM = lambda wildcards: ALIQUOT_TO_SM[PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]],
        normal_SM = lambda wildcards: ALIQUOT_TO_SM[PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]]
    threads:
        CLUSTER_META["lumpy_call"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/call/{pair_id}.log"
    benchmark:
        "benchmarks/lumpy/call/{pair_id}.txt"
    message:
        "Calling LUMPY on tumor/normal pair\n"
        "Pair: {wildcards.pair_id}"
    shell:
        "export HEXDUMP=`which hexdump || true`; "
        "lumpyexpress \
            -B {input.tumor},{input.normal} \
            -S {input.split_tumor},{input.split_normal} \
            -D {input.discordant_tumor},{input.discordant_normal} \
            -d {params.tumor_SM}:{input.bedpe_tumor},{params.normal_SM}:{input.bedpe_normal} \
            -T {config[tempdir]}/{wildcards.pair_id} \
            -x {config[svmask_lumpy]} \
            -o {output.tmp} \
            > {log} 2>&1; "
        "gatk --java-options -Xmx{params.mem}g UpdateVCFSequenceDictionary \
            -V {output.tmp} \
            --source-dictionary {config[reference_dict]} \
            --replace true \
            -O {output.vcf} \
            >> {log} 2>&1; "
        #"bgzip -i {params.vcftmpdict} && \
        #    bcftools sort -O z -o {output.vcfsorted} {output.vcf} && \
        #    bcftools index -t {output.vcfsorted} \
        #    >> {log} 2>&1"

## results/lumpy/call/GLSS-MD-LP05-TP-5AS5SI.dict.vcf
## sh bin/snakemake-run.sh -t results/lumpy/call/GLSS-MD-LP05-TP-5AS5SI.dict.vcf 

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## SVTyper
## Call genotypes using SVTyper
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule svtyper_run:
    input:
        tumor = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        normal = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]),
        vcf = "results/lumpy/call/{pair_id}.dict.vcf"
    output:
        vcf = "results/lumpy/svtyper/{pair_id}.dict.svtyper.vcf",
        stats = "results/lumpy/svtyper/{pair_id}.svtyper.json"
    params:
        mem = CLUSTER_META["svtyper_run"]["mem"]
    threads:
        CLUSTER_META["svtyper_run"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/svtyper/{pair_id}.log"
    benchmark:
        "benchmarks/lumpy/svtyper/{pair_id}.txt"
    message:
        "Calling genotypes using SVTyper\n"
        "Pair: {wildcards.pair_id}"
    shell:
        "svtyper \
            --max_reads {config[svtyper_reads]} \
            -i {input.vcf} \
            -B {input.tumor},{input.normal} \
            -l {output.stats} \
            2> {log} 1> {output.vcf}"

            #--core {threads} \
            #--batch_size {config[svtyper_batch]} \

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Library stats
## Plot insert size distribution
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule lumpy_libstat:
    input:
        "results/lumpy/svtyper/{pair_id}.svtyper.json"
    output:
        "results/lumpy/libstat/{pair_id}.libstat.pdf"
    params:
        mem = CLUSTER_META["lumpy_libstat"]["mem"]
    threads:
        CLUSTER_META["lumpy_libstat"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/libstat/{pair_id}.log"
    benchmark:
        "benchmarks/lumpy/libstat/{pair_id}.txt"
    message:
        "Plotting library statistics\n"
        "Pair: {wildcards.pair_id}"
    shell:
        "module load R; "
        "lib_stats.R {input} {output} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Filter LUMPY calls
## Using GATK
## Filters taken from:
## https://github.com/crazyhottommy/DNA-seq-analysis/blob/master/speedseq_sv_filter.md
## SU > 3
## QUAL > 10
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

## gatk VariantFiltration -V GLSS-MD-LP05-TP-5AS5SI.dict.svtyper.vcf --filter-expression "SU <= 10" --filter-name "read_support" --filter-expression "QUAL < 10" --filter-name "qual" -O tmp.vcf

# rule lumpy_filter:
#     input:
#         tumor = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
#         normal = lambda wildcards: "results/align/bqsr/{aliquot_id}.realn.mdup.bqsr.bam".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"]),
#         vcf = "results/lumpy/call/{pair_id}.dict.vcf"
#     output:
#         vcf = "results/lumpy/svtyper/{pair_id}.dict.svtyper.vcf",
#         stats = "results/lumpy/svtyper/{pair_id}.svtyper.json"
#     params:
#         mem = CLUSTER_META["svtyper_run"]["mem"]
#     threads:
#         CLUSTER_META["svtyper_run"]["ppn"]
#     conda:
#         "../envs/lumpy-sv.yaml"
#     log:
#         "logs/lumpy/svtyper/{pair_id}.log"
#     benchmark:
#         "benchmarks/lumpy/svtyper/{pair_id}.txt"
#     message:
#         "Calling genotypes using SVTyper\n"
#         "Pair: {wildcards.pair_id}"
#     shell:
#         "svtyper-sso \
#             --core {threads} \
#             --batch_size {config[svtyper_batch]} \
#             --max_reads {config[svtyper_reads]} \
#             -i {input.vcf} \
#             -B {input.tumor} \
#             -B {input.normal} \
#             -l {output.stats} \
#             2> {log} 1> {output.vcf}"

## END ##