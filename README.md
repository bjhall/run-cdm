Basic usage:

```run_stats.pl /fs1/seqdata/NovaSeq/190909_A00681_0032_BH5GKYDRXX/```

Required that demuxing is done with bcl2fastq.

RunParameters.xml must exists in the run folder root.

By default looks for Stats.json in default location (Data/Intensities/BaseCalls/Stats/Stats.json)

If a "Samplesheet.csv" in the "CMD format" exists in the run folder root it categorizes the samples into "assays".


```--statsjson``` and ```--samplesheet``` can be used to specify paths to Stats.json and a samplesheet in case they are not located in the default locations
