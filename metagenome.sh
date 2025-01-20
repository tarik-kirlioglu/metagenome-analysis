#!/bin/bash

reads="/mnt/c/users/honor/desktop/metagenomes/reads"
results="/mnt/c/users/honor/desktop/metagenomes/results"
fastqc="/mnt/c/users/honor/desktop/metagenomes/fastqc"
trimmed="/mnt/c/users/honor/desktop/metagenomes/trimmed"
minikraken="/mnt/c/users/honor/desktop/metagenome/minikraken"

echo "STEP 1:Quality Control with FASTQC"

fastqc ${reads}/*.fastq.gz -o ${fastqc}/

echo "STEP 2:Trimming and Filtering with Trimmomatic"

for infile in ${reads}/*_1.fastq.gz
do
	base=$(basename ${infile} _1.fastq.gz)
	java -jar /mnt/c/users/honor/desktop/software/Trimmomatic/dist/jar/trimmomatic-0.40-rc1.jar PE \
				${infile} ${reads}/${base}_2.fastq.gz \
                ${base}_1.trim.fastq.gz ${base}_1.untrim.fastq.gz \
                ${base}_2.trim.fastq.gz ${base}_2.untrim.fastq.gz \
                SLIDINGWINDOW:4:20 MINLEN:25 \
                ILLUMINACLIP:/mnt/c/users/honor/desktop/software/Trimmomatic/adapters/TruSeq3-PE-2.fa:2:30:10
done

mv *trim* ${trimmed}/

echo "STEP 3: Metagenome Assembly"

for infile in ${trimmed}/*_1.trim.fastq.gz
do
	base=$(basename ${infile} _1.trim.fastq.gz)
	metaspades.py -1 ${infile} -2 ${trimmed}/${base}_2.trim.fastq.gz -o ${results}/assembly_${base}

done

echo "STEP 4:Metagenome Bining"

samples=("SRR1106693" "SRR1106699")

for sample in ${samples[@]}
do
    echo "Processing sample: $sample"


    contig_file="/mnt/c/users/honor/desktop/metagenomes/results/assembly_${sample}/contigs.fasta"
    read1_file="/mnt/c/users/honor/desktop/metagenomes/trimmed/${sample}_1.trim.fastq.gz"
    read2_file="/mnt/c/users/honor/desktop/metagenomes/trimmed/${sample}_2.trim.fastq.gz"
    output_prefix="/mnt/c/users/honor/desktop/metagenomes/results/MAXBIN/${sample}"

    perl /mnt/c/users/honor/desktop/software/MaxBin-2.2.7/run_MaxBin.pl -thread 6 -contig $contig_file -reads $read1_file -reads2 $read2_file -out $output_prefix
done

echo "STEP 5:Quality Assesing of MAGs"

checkm taxonomy_wf domain Bacteria -x fasta ${results}/MAXBIN/ ${results}/CHECKM/ 

echo "STEP 6:Taxonomic Assigment"

mkdir -p ${results}/TAXONOMY_MAG

for infile in ${results}/MAXBIN/*.001.fasta
do
	base=$(basename ${infile} .001.fasta)
 
	kraken2 --db ${minikraken}/ --threads 6 -input ${infile} --output ${results}/TAXONOMY_MAG/${base}.001.kraken --report ${results}/TAXONOMY_MAG/${base}.001.report
done

echo "STEP 7:Creating Kraken to Krona File"

for infile in ${results}/TAXONOMY_MAG/*.kraken
do
	base=$(basename ${infile} .kraken)

 	cut -f2,3 ${infile} > ${results}/TAXONOMY_MAG/${base}.krona.input
done

echo "STEP 7:Visualization with Krona"

for infile in ${results}/TAXONOMY_MAG/*.krona.input
do
	base=$(basename ${infile} *.krona.input)
	
	ktImportTaxonomy ${infile} -o ${results}/TAXONOMY_MAG/${base}.krona.out.html
	
done

echo "STEP 6:Extract Biom File for Downstream Analysis"

kraken-biom ${results}/TAXONOMY_MAG/SRR1106693.001.report ${results}/TAXONOMY_MAG/SRR1106699.001.report --fmt json -o ${results}/TAXONOMY_MAG/cuatroc.biom
