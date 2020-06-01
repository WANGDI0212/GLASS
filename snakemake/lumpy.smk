## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Extract and sort split reads
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule extractsplitter:
    input:
        ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam")
    output:
        unsorted = temp("results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.unsorted.bam"),
        sorted = "results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.sorted.bam"
    params:
        prefix = "results/lumpy/split/{aliquot_barcode}",
        mem = CLUSTER_META["extractsplitter"]["mem"]
    threads:
        CLUSTER_META["extractsplitter"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/extractsplitter/{aliquot_barcode}.log"
    benchmark:
        "benchmarks/extractsplitter/{aliquot_barcode}.txt"
    message:
        "Extracting and sorting split reads\n"
        "Sample: {wildcards.aliquot_barcode}"
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
        ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam")
    output:
        unsorted = temp("results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.unsorted.bam"),
        sorted = "results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.sorted.bam"
    params:
        prefix = "results/lumpy/discordant/{aliquot_barcode}",
        mem = CLUSTER_META["extractdiscordant"]["mem"]
    threads:
        CLUSTER_META["extractdiscordant"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/extractdiscordant/{aliquot_barcode}.log"
    benchmark:
        "benchmarks/extractdiscordant/{aliquot_barcode}.txt"
    message:
        "Extracting and sorting discordant reads\n"
        "Sample: {wildcards.aliquot_barcode}"
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
        "results/cnvnator/call/{aliquot_barcode}.call.tsv"
    output:
        del_o = temp("results/lumpy/cnvbedpe/{aliquot_barcode}.del.bedpe"),
        dup_o = temp("results/lumpy/cnvbedpe/{aliquot_barcode}.dup.bedpe"),
        merged = "results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe"
    params:
        mem = CLUSTER_META["cnvnator_to_bedpe"]["mem"]
    threads:
        CLUSTER_META["cnvnator_to_bedpe"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/cnvbedpe/{aliquot_barcode}.log"
    benchmark:
        "benchmarks/lumpy/cnvbedpe/{aliquot_barcode}.txt"
    message:
        "CNVnator to BEDPE\n"
        "Sample: {wildcards.aliquot_barcode}"
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
## LUMPY (single-sample mode)
## Added HEXDUMP defintion because it was undefined for some reason
## Added gatk UpdateVCFSequenceDictionary because bcftools index requires it
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule sslumpy_call:
    input:
        tumor = lambda wildcards: ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam".format(aliquot_barcode = manifest.getTumor(wildcards.pair_barcode))),
        normal = lambda wildcards: ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam".format(aliquot_barcode = manifest.getNormal(wildcards.pair_barcode))),
        discordant_tumor = lambda wildcards: "results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.sorted.bam".format(aliquot_barcode = manifest.getTumor(wildcards.pair_barcode)),
        discordant_normal = lambda wildcards: "results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.sorted.bam".format(aliquot_barcode = manifest.getNormal(wildcards.pair_barcode)),
        split_tumor = lambda wildcards: "results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.sorted.bam".format(aliquot_barcode = manifest.getTumor(wildcards.pair_barcode)),
        split_normal = lambda wildcards: "results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.sorted.bam".format(aliquot_barcode = manifest.getNormal(wildcards.pair_barcode)),
        bedpe_tumor = lambda wildcards: "results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe".format(aliquot_barcode = manifest.getTumor(wildcards.pair_barcode)),
        bedpe_normal = lambda wildcards: "results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe".format(aliquot_barcode = manifest.getNormal(wildcards.pair_barcode))
    output:
        tmp = temp("results/lumpy/sscall/{pair_barcode}.vcf"),
        vcf = "results/lumpy/sscall/{pair_barcode}.dict.vcf"
    params:
        mem = CLUSTER_META["sslumpy_call"]["mem"],
        tumor_SM = lambda wildcards: manifest.getRGSampleTagByAliquot(manifest.getTumor(wildcards.pair_barcode)),
        normal_SM = lambda wildcards: manifest.getRGSampleTagByAliquot(manifest.getNormal(wildcards.pair_barcode))
    threads:
        CLUSTER_META["lumpy_call"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/sscall/{pair_barcode}.log"
    benchmark:
        "benchmarks/lumpy/sscall/{pair_barcode}.txt"
    message:
        "Calling LUMPY on tumor/normal pair\n"
        "Pair: {wildcards.pair_barcode}"
    shell:
        "export HEXDUMP=`which hexdump || true`; "
        "lumpyexpress \
            -B {input.tumor},{input.normal} \
            -S {input.split_tumor},{input.split_normal} \
            -D {input.discordant_tumor},{input.discordant_normal} \
            -d {params.tumor_SM}:{input.bedpe_tumor},{params.normal_SM}:{input.bedpe_normal} \
            -T {config[tempdir]}/{wildcards.pair_barcode} \
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
## LUMPY (multi-sample mode)
## Added HEXDUMP defintion because it was undefined for some reason
## Added gatk UpdateVCFSequenceDictionary because bcftools index requires it
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule lumpy_call:
    input:
        tumor = lambda wildcards: ancient(expand("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam", aliquot_barcode = manifest.getTumorByCase(wildcards.case_barcode))),
        normal = lambda wildcards: ancient(expand("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam", aliquot_barcode = manifest.getNormalByCase(wildcards.case_barcode))),
        discordant_tumor = lambda wildcards: ancient(expand("results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.sorted.bam", aliquot_barcode = manifest.getTumorByCase(wildcards.case_barcode))),
        discordant_normal = lambda wildcards: ancient(expand("results/lumpy/discordant/{aliquot_barcode}.realn.mdup.bqsr.discordant.sorted.bam", aliquot_barcode = manifest.getNormalByCase(wildcards.case_barcode))),
        split_tumor = lambda wildcards: ancient(expand("results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.sorted.bam", aliquot_barcode = manifest.getTumorByCase(wildcards.case_barcode))),
        split_normal = lambda wildcards: ancient(expand("results/lumpy/split/{aliquot_barcode}.realn.mdup.bqsr.splitters.sorted.bam", aliquot_barcode = manifest.getNormalByCase(wildcards.case_barcode))),
        bedpe_tumor = lambda wildcards: ancient(expand("results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe", aliquot_barcode = manifest.getTumorByCase(wildcards.case_barcode))),
        bedpe_normal = lambda wildcards: ancient(expand("results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe", aliquot_barcode = manifest.getNormalByCase(wildcards.case_barcode)))
    output:
        tmp = temp("results/lumpy/call/{case_barcode}.vcf"),
        vcf = "results/lumpy/call/{case_barcode}.dict.vcf"
    params:
        mem = CLUSTER_META["lumpy_call"]["mem"],
        tumor_SM = lambda wildcards: [manifest.getRGSampleTagByAliquot(s) for s in manifest.getTumorByCase(wildcards.case_barcode)],
        normal_SM = lambda wildcards: [manifest.getRGSampleTagByAliquot(s) for s in manifest.getNormalByCase(wildcards.case_barcode)],
        tumor_string = lambda _, input: ",".join(input["tumor"]),
        normal_string = lambda _, input: ",".join(input["normal"]),
        discordant_tumor_string = lambda _, input: ",".join(input["discordant_tumor"]),
        discordant_normal_string = lambda _, input: ",".join(input["discordant_normal"]),
        split_tumor_string = lambda _, input: ",".join(input["split_tumor"]),
        split_normal_string = lambda _, input: ",".join(input["split_normal"]),
        bedpe_tumor_string = lambda wildcards: ",".join([":".join([manifest.getRGSampleTagByAliquot(s), "results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe".format(aliquot_barcode = s)]) for s in manifest.getTumorByCase(wildcards.case_barcode)]),
        bedpe_normal_string = lambda wildcards: ",".join([":".join([manifest.getRGSampleTagByAliquot(s), "results/lumpy/cnvbedpe/{aliquot_barcode}.merged.bedpe".format(aliquot_barcode = s)]) for s in manifest.getNormalByCase(wildcards.case_barcode)])
    threads:
        CLUSTER_META["lumpy_call"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/call/{case_barcode}.log"
    benchmark:
        "benchmarks/lumpy/call/{case_barcode}.txt"
    message:
        "Calling LUMPY on case\n"
        "Case: {wildcards.case_barcode}"
    shell:
        "export HEXDUMP=`which hexdump || true`; "
        "lumpyexpress \
            -B {params.tumor_string},{params.normal_string} \
            -S {params.split_tumor_string},{params.split_normal_string} \
            -D {params.discordant_tumor_string},{params.discordant_normal_string} \
            -d {params.bedpe_tumor_string},{params.bedpe_normal_string} \
            -T {config[tempdir]}/{wildcards.case_barcode} \
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
## SVTyper (single-sample)
## Call genotypes using SVTyper
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule sssvtyper_run:
    input:
        tumor = lambda wildcards: ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam".format(aliquot_barcode = manifest.getTumor(wildcards.pair_barcode))),
        normal = lambda wildcards: ancient("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam".format(aliquot_barcode = manifest.getNormal(wildcards.pair_barcode))),
        vcf = "results/lumpy/sscall/{pair_barcode}.dict.vcf"
    output:
        vcf = "results/lumpy/sssvtyper/{pair_barcode}.dict.svtyper.vcf",
        stats = "results/lumpy/sssvtyper/{pair_barcode}.svtyper.json"
    params:
        mem = CLUSTER_META["sssvtyper_run"]["mem"]
    threads:
        CLUSTER_META["sssvtyper_run"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/sssvtyper/{pair_barcode}.log"
    benchmark:
        "benchmarks/lumpy/sssvtyper/{pair_barcode}.txt"
    message:
        "Calling genotypes using ss-SVTyper\n"
        "Pair: {wildcards.pair_barcode}"
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
## SVTyper
## Call genotypes using SVTyper
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule svtyper_run:
    input:
        tumor = lambda wildcards: ancient(expand("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam", aliquot_barcode = manifest.getTumorByCase(wildcards.case_barcode))),
        normal = lambda wildcards: ancient(expand("results/align/bqsr/{aliquot_barcode}.realn.mdup.bqsr.bam", aliquot_barcode = manifest.getNormalByCase(wildcards.case_barcode))),
        vcf = "results/lumpy/call/{case_barcode}.dict.vcf"
    output:
        vcf = "results/lumpy/svtyper/{case_barcode}.dict.svtyper.vcf",
        stats = "results/lumpy/svtyper/{case_barcode}.svtyper.json"
    params:
        mem = CLUSTER_META["svtyper_run"]["mem"],
        tumor_string = lambda _, input: ",".join(input["tumor"]),
        normal_string = lambda _, input: ",".join(input["normal"]),
    threads:
        CLUSTER_META["svtyper_run"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/svtyper/{case_barcode}.log"
    benchmark:
        "benchmarks/lumpy/svtyper/{case_barcode}.txt"
    message:
        "Calling genotypes using SVTyper\n"
        "Case: {wildcards.case_barcode}"
    shell:
        "svtyper \
            --max_reads {config[svtyper_reads]} \
            -i {input.vcf} \
            -B {params.tumor_string},{params.normal_string} \
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
        "results/lumpy/svtyper/{case_barcode}.svtyper.json"
    output:
        "results/lumpy/libstat/{case_barcode}.libstat.pdf"
    params:
        mem = CLUSTER_META["lumpy_libstat"]["mem"]
    threads:
        CLUSTER_META["lumpy_libstat"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/libstat/{case_barcode}.log"
    benchmark:
        "benchmarks/lumpy/libstat/{case_barcode}.txt"
    message:
        "Plotting library statistics\n"
        "Pair: {wildcards.case_barcode}"
    shell:
        "module load R; "
        "lib_stats.R {input} {output} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Library stats (single-sample)
## Plot insert size distribution
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule sslumpy_libstat:
    input:
        "results/lumpy/sssvtyper/{pair_barcode}.svtyper.json"
    output:
        "results/lumpy/sslibstat/{pair_barcode}.libstat.pdf"
    params:
        mem = CLUSTER_META["sslumpy_libstat"]["mem"]
    threads:
        CLUSTER_META["sslumpy_libstat"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/sslibstat/{pair_barcode}.log"
    benchmark:
        "benchmarks/lumpy/sslibstat/{pair_barcode}.txt"
    message:
        "Plotting library statistics\n"
        "Pair: {wildcards.pair_barcode}"
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

# gatk VariantFiltration -V tmp.vcf --filter-expression "SU <= 10" --filter-name "read_support" --filter-expression "QUAL < 10" --filter-name "qual" --filter-expression '!vc.getGenotype("GLSS-K2-0001-NB").isHomRef() || vc.getGenotype("GLSS-K2-0001-NB").getAO() > 0 || vc.getGenotype("GLSS-K2-0001-TP").isHomRef()' --filter-name "non_somatic" -O tmp.filt.vcf
# gatk VariantFiltration -V tmp.vcf --filter-expression "SU <= 10" --filter-name "read_support" --filter-expression "QUAL < 10" --filter-name "qual" --filter-expression '!vc.getGenotype(1).isHomRef() || vc.getGenotype(1).getAttributeAsInt("AO",0) > 0 || vc.getGenotype(0).isHomRef()' --filter-name "non_somatic" -O tmp.filt.vcf

rule lumpy_filter:
    input:
        "results/lumpy/svtyper/{pair_barcode}.dict.svtyper.vcf"
    output:
        "results/lumpy/filter/{pair_barcode}.dict.svtyper.filtered.vcf"
    params:
        mem = CLUSTER_META["lumpy_filter"]["mem"]
    threads:
        CLUSTER_META["lumpy_filter"]["ppn"]
    conda:
        "../envs/lumpy-sv.yaml"
    log:
        "logs/lumpy/filter/{pair_barcode}.log"
    benchmark:
        "benchmarks/lumpy/filter/{pair_barcode}.txt"
    message:
        "Filtering LUMPY sv calls\n"
        "Pair: {wildcards.pair_barcode}"
    shell:
        "gatk VariantFiltration \
            -V {input} \
            --filter-expression 'SU <= 4' \
            --filter-name 'read_support' \
            --filter-expression 'QUAL < 10' \
            --filter-name 'qual_score' \
            --filter-expression \
                '!vc.getGenotype(0).isHomRef() || \
                vc.getGenotype(0).getAttributeAsInt(\"AO\",0) > 0 || \
                vc.getGenotype(1).isHomRef()' \
            --filter-name 'non_somatic' \
            -O {output} \
            > {log} 2>&1"

## END ##