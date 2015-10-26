# Input-output using the tsv matrix, colun, and row metadata convention.

# Writes data matrix with flexible meta data to directory.
# Overwrites files in folder if named: name (provided), meta_col.tsv, or meta_row.tsv.
# Does not check if the metadata files are compatible when overwritten.
# Encapsulate the data format
writeDataCore = function(mat, meta_col, meta_row, target_dir, name="data") {
	if (ncol(mat) != nrow(meta_col)) {
		stop("Column metadata and data matrix dimensions are not compatible.")
	}

	if (nrow(mat) != nrow(meta_row)) {
		stop("Row metadata and data matrix dimensions are not compatible.")
	}

	# Write main data matrix
	write.table(mat, file=paste0(target_dir, "/", name, ".tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	# Write metadata
	write.table(meta_row, file=paste0(target_dir, "/meta_row.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
	write.table(meta_col, file=paste0(target_dir, "/meta_col.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
}

# Wrapper function for writeDataCore where input is dataframe with $x, $meta_col, and $meta_row
writeData = function(d, target_dir=".", file_format="hdf5") {
	require(rhdf5)

	# Check if directory exists
	dir.create(target_dir)  # prints warning if directory already exists


	if (file_format == "hdf5") {
		if (file.exists(paste0(target_dir, "/data.h5"))) {
			# remove previous file
			unlink(paste0(target_dir, "/data.h5"))
		}
		h5createFile(paste0(target_dir, "/data.h5"))

		 # else overwrite existing file
		for (entry in names(d)) {
			if (entry == "meta_col" || entry == "meta_row") {
				# convert factors to characters (otherwise the factor labels are converted to integers).
				factor_cols = sapply(d[[entry]], class) == "factor"  # the columns which are factors
				# construct new data frame where strings are not encoded using factors.
				d[[entry]][,factor_cols] = data.frame(
					lapply(d[[entry]][,factor_cols, drop=FALSE], as.character),
					stringsAsFactors=FALSE)
			}
			# write data to HDF5 file
			h5write(d[[entry]], paste0(target_dir, "/data.h5"), entry)
			H5close()
		}
	} else if (file_format == "txt") {
		# Plain text format
		# Loop over entries in data list
		for (entry in names(d)) {
			if (entry == "meta_col" || entry == "meta_row") {
				next  # skip, meat data is (over)written for each entry
			}

			writeDataCore(d[[entry]],
				meta_col=d$meta_col, 
				meta_row=d$meta_row,
				target_dir=target_dir,
				name=entry)
		}
	} else {
		stop("Wrong file_format")
	}
}

# returns list with main data, meta_row, and meta_col. 
# if name is a vector multiple files are loaded
# Reads data from specified folder.
# names=NULL loads all entries
readData = function(dir=".", names=NULL, file_format="hdf5") {
	require(rhdf5)
	# options(stringsAsFactors=FALSE)  # WARNING: forces global options to change...
	d = list()

	if (file_format == "hdf5") {
		d = h5read(paste0(dir, "/data.h5"), "/")
		H5close()
	} else if (file_format == "txt") {
		# Load metadata
		d$meta_row = fread(paste0(dir, "/meta_row.tsv"), header=TRUE, sep="auto", stringsAsFactors=FALSE)
		d$meta_col = fread(paste0(dir, "/meta_col.tsv"), header=TRUE, sep="auto", stringsAsFactors=FALSE)

		# Load main data entries
		for (entry in names) {
			d[[entry]] = fread(paste0(dir, "/", entry, ".tsv"), header=FALSE, sep="auto")
			d[[entry]] = matrix(as.numeric(as.matrix(d[[entry]])), nrow=nrow(d[[entry]]))  # numeric data matrix

			# Check dimensions of the loaded main data.
			if (ncol(d[[entry]]) != nrow(d$meta_col)) {
				stop("Column metadata and data matrix dimensions are not compatible.")
			}

			if (nrow(d[[entry]]) != nrow(d$meta_row)) {
				stop("Row metadata and data matrix dimensions are not compatible.")
			}
		}
	} else {
		stop("wrong file_format")
	}

	# Check if valid
	checkDataList(d)

	return(d)
}

# Makes a folder in target directory and writes correlation data as flat files following
# naming conventions.
writeCorData = function(d, target_dir=".") {
	require(RJSONIO)
	require(random)
	checkCorList(d)

	# write.table(mat, file=paste0(target_dir, "/", name, ".tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	# # Write metadata
	# write.table(meta_row, file=paste0(target_dir, "/meta_row.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
	# write.table(meta_col, file=paste0(target_dir, "/meta_col.tsv"), quote=FALSE, row.names=FALSE, sep="\t")

	# Create random folder name for the data files
	folder_name = randomStrings(1, len=20)[1, 1]
	folder_path = paste0(target_dir, "/", folder_name)
	dir.create(folder_path)

	write.table(d$A, file=paste0(folder_path, "/A.tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	write.table(d$B, file=paste0(folder_path, "/B.tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	write.table(d$AT, file=paste0(folder_path, "/AT.tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	write.table(d$BT, file=paste0(folder_path, "/BT.tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")
	write.table(d$ATBT, file=paste0(folder_path, "/ATBT.tsv"), quote=FALSE, row.names=FALSE, col.names=FALSE, sep="\t")

	write.table(d$meta_rowA, file=paste0(folder_path, "/meta_rowA.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
	write.table(d$meta_colA, file=paste0(folder_path, "/meta_colA.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
	write.table(d$meta_rowB, file=paste0(folder_path, "/meta_rowB.tsv"), quote=FALSE, row.names=FALSE, sep="\t")
	write.table(d$meta_colB, file=paste0(folder_path, "/meta_colB.tsv"), quote=FALSE, row.names=FALSE, sep="\t")

	d$invoke$id = folder_name
	invoke = toJSON(d$invoke)
	write(invoke, paste0(folder_path, "/invoke.json"))
}