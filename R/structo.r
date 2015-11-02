# Data structure operations.

# Data structures
# ----------------------------------------------------------
# The main data strucutre is an implicit data strucutre
# based on an R list. THe list has entries $meta_col for 
# sample metadata and $meta_row for row metadata. All other
# list entries are primary data matrices matching the dimensions
# of the meta data.

# Test if the list is a valid bdmerge data list. Throws errors if invalid.
checkDataList = function(d) {

	if (class(d) != "list") {
		stop("ERROR: Invalid data type, not a list.")
	}

	if (!("meta_row" %in% names(d))) {
		stop("ERROR: Invalid data type, list does not contain meta_row entry.")
	}

	if (!("meta_row" %in% names(d))) {
		stop("ERROR: Invalid data type, list does not contain meta_row entry.")
	}


	if (!("meta_col" %in% names(d))) {
		stop("ERROR: Invalid data type, list does not contain meta_col entry.")
	}

	for (entry in names(d)) {
		if (entry == "meta_row" || entry == "meta_col") {
			next
		}

		# Test dimensions of data matrix
		if (nrow(d[[entry]]) != nrow(d$meta_row)) {
			stop("ERROR: Invalid data type, dimension mismatch between meta_row and ", entry)
		}
	}

	return(TRUE)  # all tests passed
}

# Some data structure checks for the matched correlation structure generated by corMerge()
checkCorList = function(d) {
	if (class(d) != "list") {
		stop("ERROR: cor data type is not a list")
	}

	req_names = c("A", "B", "ATBT", "meta_rowA", "meta_colA", "meta_rowB", "meta_colB", "invoke")

	if (any(! req_names %in% names(d))) {
		stop("ERROR: invalid list names")
	}

	return(TRUE)
}

	
# Returns the column subset of a bdmerge data list.
# sample_num: a vector of the sample ids
# d is a bdmerge data list
colSubset = function(d, samples) {

	if (class(samples) == "logical") {
		samples = which(samples)
	}

	if (!all(samples <= nsamples(d))) {
		stop("samples is out of bounds")
	}

	if (!all(samples > 0)) {
		stop("samples is out of bounds")
	}

	out = list()

	out$meta_row = d$meta_row
	out$meta_col = d$meta_col[samples, , drop=FALSE]
	out$meta_col = as.data.frame(out$meta_col)  # 

	for (entry in names(d)) {
		if (entry == "meta_row" || entry == "meta_col") next

		out[[entry]] = d[[entry]][,samples]
	}
	checkDataList(out)
	return(out)
}

# d is a dlist, exp_def a vector defining experimental id
colUnique = function(d, exp_def) {
	experiments = apply(d$meta_col[exp_def], 1, paste, collapse=":")

	unique_samples = match(unique(experiments), experiments)  # first match only

	# Remove all sample definitions with missing values
	return(colSubset(d, unique_samples))
}

# Extract columns from matched list of data lists.
colSubsetMatchedCollection = function(dlists, samples) {
	out = list(0)
	for (i in 1:length(dlists)) {
		out[[i]] = colSubset(dlists[[i]], samples)
	}
	return(out)
}

# Rename matrix columns. Returns modified dlist.
labelMatrixCols = function(d, col_name_def, dec=1) {

	# Extract naming subset
	name_frame = d$meta_col[col_name_def]

	# Round numeric entries
	name_type = sapply(name_frame, class)

	for (i in 1:ncol(name_frame)) {
		if (name_type[i] == "numeric") {
			name_frame[,i] = round(name_frame[,i], dec)
		}
	}

	# Construct labels
	lables = apply(name_frame, 1, paste, collapse=":")

	lables = gsub(" ", "", lables)  # remove all white space 

	for (entry in names(d)) {
		if (entry == "meta_col" | entry == "meta_row") next

		colnames(d[[entry]]) = lables
	}

	return(d)
}

labelMatrixRows = function(d, row_name_def, dec=1) {
	# Extract naming subset
	name_frame = d$meta_row[row_name_def]

	# Round numeric entries
	name_type = sapply(name_frame, class)

	for (i in 1:ncol(name_frame)) {
		if (name_type[i] == "numeric") {
			name_frame[,i] = round(name_frame[,i], dec)
		}
	}

	lables = apply(name_frame, 1, paste, collapse=":")

	lables = gsub(" ", "", lables)  # remove white space

	for (entry in names(d)) {
		if (entry == "meta_col" | entry == "meta_row") next

		rownames(d[[entry]]) = lables
	}

	return(d)
}


nsamples = function(d) {
	tryCatch(checkDataList(d),
		# on any error, callback
		error=function(e) {
			# Prints error and proceeds
			message(e$message)
		}
	)

	return(nrow(d$meta_col))
}

nfeatures = function(d) {
	tryCatch(checkDataList(d),
		# on any error, callback
		error=function(e) {
			# Prints error and proceeds
			message(e$message)
		}
	)

	return(nrow(d$meta_row))
}

nmatrices = function(d) {
	tryCatch(checkDataList(d),
		# on any error, callback
		error=function(e) {
			# Prints error and proceeds
			message(e$message)
		}
	)

	return(length(d) - 2)
}

# Counts the number of missing values per column of each dlist in a provided list. entry is the name of the data table.
missingValuesCol = function(dlists, entry) {
	missing = lapply(dlists, function(dlist) {
		col_missing = apply(dlist[[entry]], 2, function(col) {
			return(sum(is.na(col)))
		})
		return(col_missing)
	})
	return(missing)
}

# entry is a vector of matrix names in dlists. If single entry name is provided
# the same name is assumed for all.
allMissingValuesCol = function(dlists, entries) {

	if (length(entries) == 1) {
		entries = rep(entries, length(dlists))  # expand to match length of list
	}

	# make references to matrix
	matrices = list()
	for (i in 1:length(dlists)) {
		matrices[[i]] = dlists[[i]][[entries[i]]]
	}

	missing = lapply(matrices, function(mat) {
		col_missing = apply(mat, 2, function(col) {
			return(all(is.na(col)))
		})
		return(col_missing)
	})

	return(missing)
}




# Operations
# --------------------------------------------------------------

# Merges data lists. Includes common features indicated by the row_id.
# Column meta data are expanded.
mergeDataListsByRow = function(dlist1, dlist2, row_id="id") {
	require("plyr")  # todo: move dependency to NAMESPACE file

	# Defensive check for valid data lists.
	checkDataList(dlist1)
	checkDataList(dlist2)

	# Test if provided row_id is valid
	if (!all(row_id %in% colnames(dlist1$meta_row))) {
		stop("invalid row_id not found in meta_row: ", row_id)
	}
	if (!all(row_id %in% colnames(dlist2$meta_row))) {
		stop("invalid row_id not found in meta_row: ", row_id)
	}

	# Output data lists structure
	out = list()

	# out$meta_row = merge(dlist1$meta_row, dlist2$meta_row, by=row_id)  # default inner join, only includes common rows
	out$meta_row = merge(dlist1$meta_row, dlist2$meta_row, all=TRUE)  # outer join, all rows are included

	# Expand column meta data (samples)
	out$meta_col = rbind.fill(dlist1$meta_col, dlist2$meta_col)

	for (entry in names(dlist1)) {
		if (entry == "meta_row" | entry == "meta_col") next  # excludes meta data

		mat1 = matrix(NA, nrow=nrow(out$meta_row), ncol=nsamples(dlist1))
		mat2 = matrix(NA, nrow=nrow(out$meta_row), ncol=nsamples(dlist2))

		row_order1 = match(dlist1$meta_row[[row_id]], out$meta_row[[row_id]])
		row_order2 = match(dlist2$meta_row[[row_id]], out$meta_row[[row_id]])

		mat1[row_order1,] = dlist1[[entry]]
		mat2[row_order2,] = dlist2[[entry]]

		out[[entry]] = cbind(mat1, mat2)
	}

	checkDataList(out)

	return(out)
}


mergeDataLists = function(dlist1, dlist2) {

	# out$meta_col = merge(dlist1$meta_col, dlist2$meta_col, all.y=TRUE)
	# out$meta_col = dlist1$meta_col[col_index1,]

	# meta_col1 = dlist1$meta_col[col_index1,]
	# names(meta_col1) = paste0(names(meta_col1), "1")
	# meta_col2 = dlist2$meta_col[col_index2,]
	# names(meta_col2) = paste0(names(meta_col2), "2")
	# out$meta_col = cbind(meta_col1, meta_col2)

	# out$meta_col = cbind(dlist1$meta_col, dlist2$meta_col)

	out = list()
	out$meta_col = rbind.fill(dlist1$meta_col, dlist2$meta_col)

	# out$meta_row = rbind.fill(dlist1$meta_row, dlist2$meta_row)
	out$meta_row = merge(dlist1$meta_row, dlist2$meta_row)  # default inner join


	for (entry in names(dlist1)) {
		if (entry == "meta_row" | entry == "meta_col") next

		out[[entry]] = cbind(
			dlist1[[entry]], 
			dlist2[[entry]])
	}

	checkDataList(out)
	return(out)
}

# Merges data types with matching column condition (such as experimental id). 
# Uses cyclical sampling without replacement to fill in the lesser data type for each condition.
# First, matching index vectors are calculated, which are used to slice the two input data lists.
# Only column metadata is combined using cbind. THerefore, column names migth be replicated.
# max_repat: maximum number of allowed repetitions in data matchings.
# output: "rjoin_matrix": matrices are joined by row
#			"matched_matrix": matrices are returned with corresponding indices
# mergeDataListsByCol = function(dlist1, dlist2, match_condition, 
mergeDataListsByCol = function(dlists, 
	match_conditions,  # list of vectors generating
	bootstrap=FALSE)
{
	require(plyr)

	# # test enviroment 
	# match_condition=c("cell_id", "pert_id", "pert_dose")
	# # dlists = list(p100_ttest, l1000_ttest)
	# dlists = list(p100_ttest, l1000_ttest_6h, l1000_ttest_24h)
	# bootstrap = TRUE

	if (length(match_conditions) == 1 & length(dlists) > 1) {
		# repeat match_conditions
		match_conditions = rep(list(match_conditions), length(dlists))
	}

	if (!length(match_conditions) == length(dlists)) {
		stop("Data lists and match_conditions do not agree")
	}

	# Check and format
	for (j in 1:length(dlists)) {
		checkDataList(dlists[[j]])

		# Test if provided row_id is valid
		if (!all(match_conditions[[j]] %in% colnames(dlists[[j]]$meta_col))) {
			stop("invalid col id not found in meta_col: ", match_conditions[[j]])
		}

		dlists[[j]]$meta_col = as.data.frame(dlists[[j]]$meta_col)
		dlists[[j]]$meta_row = as.data.frame(dlists[[j]]$meta_row)

		# Check match condition and ensure consistent string format
		for (k in 1:length(match_conditions[[j]])) {
			if (class(dlists[[j]]$meta_col[[match_conditions[[j]][[k]]]]) == "integer" | 
				class(dlists[[j]]$meta_col[[match_conditions[[j]][[k]]]]) == "numeric")
			{
				dlists[[j]]$meta_col[[match_conditions[[j]][k]]] = format(as.numeric(dlists[[j]]$meta_col[[match_conditions[[j]][k]]]), nsmall=1, trim=TRUE)
			}
		}
	}

	for (j in 2:length(dlists)) {
		if (!all(names(dlists[[j - 1]]) == names(dlists[[j]]))) {
			stop("Data lists contain different entries.")
		}
	}

	# Construct group ids
	sampleids = list()
	for (j in 1:length(dlists)) {
		sampleids[[j]] = apply(dlists[[j]]$meta_col[unlist(match_conditions[[j]])], 1, paste, collapse=":")
		sampleids[[j]] = gsub(" ", "", sampleids[[j]])  # remove any whitespace
	}

	# groups = unique(c(sampleid1, sampleid2))
	groups = unique(unlist(sampleids))

	# Create mathcing local column index accross each of the dlists
	col_index = list()

	# Loop over experimental groups
	# for (i in 13:14) {
	for (i in 1:length(groups)) {

		# Find the local columns for each data list that matches the experimental group.
		cols = lapply(sampleids, function(ids) {
			local_index = which(ids == groups[i])
			if (length(local_index) == 0) {
				return(NA)  
			} else {
				return(local_index)
			}
		})

		# Shuffle order
		cols = lapply(cols, function(local_index) {
			return(local_index[sample(1:length(local_index))])
		})

		max_members = max(sapply(cols, length))

		# sample with replacement to maximum samples for other data types
		if (bootstrap) {
			cols = lapply(cols, function(local_index) {
				if (length(local_index) == max_members | length(local_index) == 0) {
					return(local_index)
				} else if (length(local_index) == 1) {
					return(rep(local_index, max_members - length(local_index) + 1))
				} else if (length(local_index) > 1) {
					return(
						sample(local_index, size=max_members, replace=TRUE)
					)
				} else {
					stop("Invalid local_index")  # internal error
				}
			})
		} else {
			# no bootstrap, fill up with NA's
			cols = lapply(cols, function(local_index) {
				if (length(local_index) == max_members) {
					return(local_index)
				} else {
					return(c(local_index, rep(NA, max_members - length(local_index))))
				}
			})
		}
		col_index[[i]] = do.call(cbind, cols)
	}

	# Matrix of local (and matched) indicies. One column per dlist
	col_index_mat = do.call(rbind, 	col_index)

	group_members = sapply(col_index, nrow)

	if (!length(group_members) == length(groups)) {
		stop("Internal, match group inconsistency")
	}

	if (!length(group_members) == length(col_index)) {
		stop("Internal, match group and col index inconsistent.")
	}

	match_group = list()
	for (k in 1:length(group_members)) {
		match_group[[k]] = rep(k, nrow(col_index[[k]]))
	}
	match_group = unlist(match_group)

	# match_groups = sapply(sapply(col_index, nrow), sqrt)

	# Slice the input data lists using the calculated column indices.
	out = list()

	for (j in 1:length(dlists)) {
		out[[j]] = list()
		out[[j]]$meta_col = dlists[[j]]$meta_col[col_index_mat[,j],]
		out[[j]]$meta_col$match_group = match_group
		out[[j]]$meta_row = dlists[[j]]$meta_row

		for (entry in names(dlists[[j]])) {
			if (entry == "meta_row" | entry == "meta_col") next
			out[[j]][[entry]] = dlists[[j]][[entry]][,col_index_mat[,j]]
		}

		checkDataList(out[[j]])
	}

	return(out)
}


# mergeDataListsByColLegacy = function(dlist1, dlist2, match_condition, 
# 	max_repeat=3, output_format="rjoin_matrix")
# {
# 	require(plyr)

# 	# # test enviroment
# 	# match_condition=c("cell_id", "pert_id")
# 	# max_repeat = 3
# 	# dlist1 = ttest
# 	# dlist2 = p100_ttest

# 	checkDataList(dlist1)
# 	checkDataList(dlist2)

# 	# Ensure that column meta data is a data frame.
# 	dlist1$meta_col = as.data.frame(dlist1$meta_col)
# 	dlist2$meta_col = as.data.frame(dlist2$meta_col)

# 	dlist1$meta_row = as.data.frame(dlist1$meta_row)
# 	dlist2$meta_row = as.data.frame(dlist2$meta_row)

# 	# Test if provided row_id is valid
# 	if (!all(match_condition %in% colnames(dlist1$meta_col))) {
# 		stop("invalid col id not found in meta_col: ", match_condition)
# 	}
# 	if (!all(match_condition %in% colnames(dlist2$meta_col))) {
# 		stop("invalid col id not found in meta_col: ", match_condition)
# 	}

# 	# Test that provided lists contains the same entreis
# 	if (!all(names(dlist1) == names(dlist2))) {
# 		stop("Data lists contain different entries.")
# 	}

# 	# Construct group ids
# 	sampleid1 = apply(dlist1$meta_col[match_condition], 1, paste, collapse=":")
# 	sampleid1 = gsub(" ", "", sampleid1)  # remove all whitespace
# 	sampleid2 = apply(dlist2$meta_col[match_condition], 1, paste, collapse=":")
# 	sampleid2 = gsub(" ", "", sampleid2)  # remove all whitespace

# 	groups = unique(c(sampleid1, sampleid2))

# 	col_index1 = list()
# 	col_index2 = list()
# 	for (i in 1:length(groups)) {
# 		cols1 = which(sampleid1 == groups[i])
# 		cols2 = which(sampleid2 == groups[i])

# 		if (length(cols1) == 0) {
# 			cols1 = NA
# 		}

# 		if (length(cols2) == 0) {
# 			cols2 = NA
# 		}

# 		if (length(cols1) == 1) {
# 			# only one data point of type 1
# 			col_index1[[i]] = rep(cols1, length(cols2))
# 			col_index2[[i]] = cols2
# 		} else if (length(cols2) == 1) {
# 			col_index1[[i]] = cols1
# 			col_index2[[i]] = rep(cols2, length(cols1))

# 		} else if (length(cols1) == length(cols2)) {
# 			# same number of data points, randomize order of matching
# 			col_index1[[i]] = cols1
# 			col_index2[[i]] = sample(cols2, replace=FALSE)
# 		} else if (length(cols1) > length(cols2)){
# 			col_index1[[i]] = cols1

# 			# fill in data of second type
# 			quotient = length(cols1) %/% length(cols2)
# 			remainder = length(cols1) %% length(cols2)

# 			cycle_index = as.vector(
# 				replicate(quotient, sample(cols2, replace=FALSE))
# 			)
# 			remainder_index = sample(cols2, size=remainder, replace=FALSE)

# 			col_index2[[i]] = c(cycle_index, remainder_index)
# 		} else {
# 			# length(cols2) > length(cols1)
# 			col_index2[[i]] = cols2

# 			quotient = length(cols2) %/% length(cols1)
# 			remainder = length(cols2) %% length(cols1)

# 			cycle_index = as.vector(
# 				replicate(quotient, sample(cols1, replace=FALSE))
# 			)
# 			remainder_index = sample(cols1, size=remainder, replace=FALSE)

# 			col_index1[[i]] = c(cycle_index, remainder_index)
# 		}
# 	}

# 	col_index1 = unlist(col_index1)
# 	col_index2 = unlist(col_index2)

# 	# Calculate the number of each data index that needs to be removed in order to satisfy the maximum
# 	# data repeatability criteria.
# 	# named vector of the number of data points to remove
# 	remove1 = table(col_index1) - max_repeat
# 	remove1 = remove1[remove1 > 0]
# 	remove2 = table(col_index2) - max_repeat
# 	remove2 = remove2[remove2 > 0]

# 	if (length(remove1) > 0) {
# 		for (i in 1:length(remove1)) {
# 			# print(i)
# 			index = as.numeric(names(remove1[i]))  # data index
# 			nrem = remove1[i]  # number of entries to remove (multiplicity)

# 			index_remove = sample(which(col_index1 == index), nrem)
# 			col_index1[index_remove] = NA
# 		}
# 	}

# 	if (length(remove2) > 0) {
# 		for (i in 1:length(remove2)) {
# 			# print(i)
# 			index = as.numeric(names(remove2[i]))  # data index
# 			nrem = remove2[i]  # number of entries to remove (multiplicity)

# 			index_remove = sample(which(col_index2 == index), nrem)
# 			col_index2[index_remove] = NA
# 		}
# 	}


# 	# Slice the input data lists using the calculated column indices.
# 	out = list()
# 	# out$meta_col = rbind.fill(dlist1$meta_col[col_index1,], dlist2$meta_col[col_index2,])
# 	# out$meta_col = merge(dlist1$meta_col[col_index1,], dlist2$meta_col[col_index2,], all.y=TRUE)
# 	# out$meta_col = dlist1$meta_col[col_index1,]


# 	# meta_col1 = dlist1$meta_col[col_index1,]
# 	# names(meta_col1) = paste0(names(meta_col1), "1")
# 	# meta_col2 = dlist2$meta_col[col_index2,]
# 	# names(meta_col2) = paste0(names(meta_col2), "2")
# 	# out$meta_col = cbind(meta_col1, meta_col2)

# 	if (output_format == "rjoin_matrix") {
# 		out$meta_col = cbind(dlist1$meta_col[col_index1,], dlist2$meta_col[col_index2,])

# 		out$meta_row = rbind.fill(dlist1$meta_row, dlist2$meta_row)

# 		for (entry in names(dlist1)) {
# 			if (entry == "meta_row" | entry == "meta_col") next

# 			out[[entry]] = rbind(
# 				dlist1[[entry]][,col_index1], 
# 				dlist2[[entry]][,col_index2])
# 		}

# 		checkDataList(out)

# 	} else if (output_format == "matched_matrix") {
# 		out[[1]] = list()
# 		out[[2]] = list()

# 		out[[1]]$meta_col = dlist1$meta_col[col_index1,]
# 		out[[2]]$meta_col = dlist2$meta_col[col_index2,]

# 		out[[1]]$meta_row = dlist1$meta_row
# 		out[[2]]$meta_row = dlist2$meta_row

# 		for (entry in intersect(names(dlist1), names(dlist2))) {
# 			if (entry == "meta_col" || entry == "meta_row") next

# 			out[[1]][[entry]] = dlist1[[entry]][,col_index1]
# 			out[[2]][[entry]] = dlist2[[entry]][,col_index2]
# 		}
# 		checkDataList(out[[1]])
# 		checkDataList(out[[2]])
# 	}


# 	return(out)
# }

