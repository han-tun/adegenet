#############
## find.clusters
#############
find.clusters <- function (x, ...) UseMethod("find.clusters")

############################
#' @method find.clusters data.frame
#' @export
find.clusters.data.frame <- function(x, clust = NULL, n.pca = NULL, n.clust = NULL,
                                     method = c("kmeans", "ward"),
                                     stat = c("BIC", "AIC", "WSS"), choose.n.clust = TRUE,
                                     criterion = c("diffNgroup", "min", "goesup",
                                                   "smoothNgoesup", "goodfit"),
                                     max.n.clust = round(nrow(x)/10), n.iter = 1e5,
                                     n.start = 10, center = TRUE, scale = TRUE,
                                     pca.select = c("nbEig","percVar"),
                                     perc.pca = NULL, ..., dudi = NULL){

    ## CHECKS ##
    stat <- match.arg(stat)
    pca.select <- match.arg(pca.select)
    criterion <- match.arg(criterion)
    min.n.clust <- 2
    max.n.clust <- max(max.n.clust, 2)
    method <- match.arg(method)
    
    ## KEEP TRACK OF SOME ORIGINAL PARAMETERS
    ## n.pca.ori <- n.pca
    ##n.clust.ori <- n.clust


    ## ESCAPE IF SUB-CLUST ARE SEEKED ##
    if(!is.null(clust)){
        res <- .find.sub.clusters(x = x, clust = clust, n.pca = n.pca,
                                  n.clust = n.clust, stat = stat,
                                  max.n.clust = max.n.clust,
                                  n.iter = n.iter, n.start = n.start,
                                  choose.n.clust = choose.n.clust,
                                  criterion = criterion,
                                  method = method,
                                  center = center, scale = scale)
        return(res)
    }
    ## END SUB-CLUST


    ## PERFORM PCA ##
    N <- nrow(x)
    REDUCEDIM <- is.null(dudi)

    if(REDUCEDIM){ # if no dudi provided
        ## PERFORM PCA ##
        maxRank <- min(dim(x))
        pcaX <- dudi.pca(x, center = center, scale = scale, scannf = FALSE, nf=maxRank)
    } else { # else use the provided dudi
        pcaX <- dudi
    }
    cumVar <- 100 * cumsum(pcaX$eig)/sum(pcaX$eig)

    if(!REDUCEDIM){
        myCol <- rep(c("black", "lightgrey"), c(ncol(pcaX$li),length(pcaX$eig)))
    } else {
        myCol <- "black"
    }

    ## select the number of retained PC for PCA
    if(is.null(n.pca) & pca.select == "nbEig"){
        plot(cumVar, xlab = "Number of retained PCs",
             ylab = "Cumulative variance (%)",
             main = "Variance explained by PCA",
             col = myCol)
        cat("Choose the number PCs to retain (>= 1): ")
        n.pca <- as.integer(readLines(con = getOption('adegenet.testcon'), n = 1))
    }

    if(is.null(perc.pca) & pca.select == "percVar"){
        plot(cumVar, xlab = "Number of retained PCs",
             ylab = "Cumulative variance (%)",
             main = "Variance explained by PCA",
             col = myCol)
        cat("Choose the percentage of variance to retain (0-100): ")
        nperc.pca <- as.numeric(readLines(con = getOption('adegenet.testcon'), n = 1))
    }

    ## get n.pca from the % of variance to conserve
    if(!is.null(perc.pca)){
        n.pca <- min(which(cumVar >= perc.pca))
        if(perc.pca > 99.999) n.pca <- length(pcaX$eig)
        if(n.pca<1) n.pca <- 1
    }


     ## keep relevant PCs - stored in XU
    X.rank <- length(pcaX$eig)
    n.pca <- min(X.rank, n.pca)
    if(n.pca >= N) warning("number of retained PCs of PCA is greater than N")
    ##if(n.pca > N/3) warning("number of retained PCs of PCA may be too large (> N /3)")

    XU <- pcaX$li[, 1:n.pca, drop=FALSE] # principal components

    ## PERFORM K-MEANS
    if(is.null(n.clust)){
        nbClust <- min.n.clust:max.n.clust
        WSS <- numeric(0)

        for(i in 1:length(nbClust)){
            if (method == "kmeans") {
                ## kmeans clustering (original method)
                temp <- kmeans(XU, centers = nbClust[i], iter.max = n.iter, nstart = n.start)
                ##WSS[i] <- sum(temp$withinss)
            } else {
                ## ward clustering
                temp <- list()
                temp$cluster <- cutree(hclust(dist(XU)^2, method = "ward.D2"), k = nbClust[i])
            }
                WSS[i] <- .compute.wss(XU, temp$cluster)
            
        }


        ## DETERMINE THE NUMBER OF GROUPS
        ##TSS <- sum(pcaX$eig) * N
        ##betweenVar <- (1 - ((stat/(N-nbClust-1))/(TSS/(N-1)) )) *100
        ##WSS.ori <- sum(apply(XU, 2, function(v) sum((v-mean(v))^2) ))
        ##reducWSS <- -diff(c(WSS.ori, stat))
        ##reducWSS <- reducWSS/max(reducWSS)

        if(stat=="AIC"){
            WSS.ori <- sum(apply(XU, 2, function(v) sum((v-mean(v))^2) ))
            k <- nbClust
            myStat <- N*log(c(WSS.ori,WSS)/N) + 2*c(1,nbClust)
            myLab <- "AIC"
            myTitle <- "Value of AIC \nversus number of clusters"

        }
        if(stat=="BIC"){
            WSS.ori <- sum(apply(XU, 2, function(v) sum((v-mean(v))^2) ))
            k <- nbClust
            myStat <- N*log(c(WSS.ori,WSS)/N) + log(N) *c(1,nbClust)
            myLab <- "BIC"
            myTitle <- "Value of BIC \nversus number of clusters"
        }
        if(stat=="WSS"){
            WSS.ori <- sum(apply(XU, 2, function(v) sum((v-mean(v))^2) ))
            myStat <- c(WSS.ori, WSS)
            ##            reducWSS <- -diff(c(WSS.ori, stat))
            ##            myStat <- reducWSS/max(reducWSS)
            myLab <- "Within sum of squares"
            myTitle <- "Value of within SS\nversus number of clusters"
        }

        if(choose.n.clust){
            plot(c(1,nbClust), myStat, xlab = "Number of clusters",
                 ylab = myLab, main = myTitle, type = "o", col = "blue")
            abline(h=0, lty=2, col="red")
            cat("Choose the number of clusters (>=2): ")
            n.clust <- NA
            while(is.na(n.clust)){
                n.clust <- max(1, as.integer(readLines(con = getOption('adegenet.testcon'), n = 1)))
            }
        } else {
            if(criterion=="min") {
                n.clust <- which.min(myStat)
            }
            if(criterion=="goesup") {
                ## temp <- diff(myStat)
                ## n.clust <- which.max( which( (temp-min(temp))<max(temp)/1e4))
                n.clust <- min(which(diff(myStat)>0))
            }
            if(criterion=="goodfit") {
                temp <- min(myStat) + 0.1*(max(myStat) - min(myStat))
                n.clust <- min( which(myStat < temp))-1
            }
            if(criterion=="diffNgroup") {
                temp <- cutree(hclust(dist(diff(myStat)), method="ward.D"), k=2)
                goodgrp <- which.min(tapply(diff(myStat), temp, mean))
                n.clust <- max(which(temp==goodgrp))+1
            }
            if(criterion=="smoothNgoesup") {
                temp <- myStat
                temp[2:(length(myStat)-1)] <- sapply(1:(length(myStat)-2),
                                                     function(i) mean(myStat[c(i,i+1,i+2)]))
                n.clust <- min(which(diff(temp)>0))
            }

        }
    } else { # if n.clust provided
        myStat <- NULL
    }

    ## get final groups
    if(n.clust >1){
        if (method == "kmeans") {
            best <-  kmeans(XU, centers = n.clust, iter.max = n.iter,
                            nstart = n.start)
        } else {
            best <- list()
            best$cluster <- cutree(hclust(dist(XU)^2, method = "ward.D2"),
                               k = n.clust)
            best$size <- table(best$cluster)
        }
         
    } else {
        best <- list(cluster=factor(rep(1,N)), size=N)
    }


    ## MAKE RESULT ##
    if(!is.null(myStat)){
        names(myStat) <- paste("K",c(1,nbClust), sep="=")
    }

    res <- list(Kstat=myStat, stat=myStat[n.clust], grp=factor(best$cluster), size=best$size)

    return(res)
} # end find.clusters.data.frame






########################
#' @method find.clusters genind
#' @export
########################
find.clusters.genind <- function(x, clust = NULL, n.pca = NULL, n.clust = NULL, 
                                 method = c("kmeans", "ward"),
                                 stat = c("BIC", "AIC", "WSS"),
                                 choose.n.clust=TRUE, 
                                 criterion = c("diffNgroup", "min","goesup", "smoothNgoesup", "goodfit"),
                                 max.n.clust = round(nrow(x@tab)/10), n.iter = 1e5, n.start = 10,
                                 scale = FALSE, truenames = TRUE, ...){

    ## CHECKS ##
    if(!is.genind(x)) stop("x must be a genind object.")
    stat <- match.arg(stat)


    ## SOME GENERAL VARIABLES ##
    N <- nrow(x@tab)
    min.n.clust <- 2

    ## PERFORM PCA ##
    maxRank <- min(dim(x@tab))

    X <- scaleGen(x, center = TRUE, scale = scale,
                  NA.method = "mean")

    ## CALL DATA.FRAME METHOD
    res <- find.clusters(X, clust=clust, n.pca=n.pca, n.clust=n.clust, stat=stat,
                         max.n.clust=max.n.clust, n.iter=n.iter, n.start=n.start,
                         choose.n.clust=choose.n.clust, method = method,
                         criterion=criterion, center=FALSE, scale=FALSE,...)
    return(res)
} # end find.clusters.genind





###################
#' @method find.clusters matrix
#' @export
###################
find.clusters.matrix <- function(x, ...){
    return(find.clusters(as.data.frame(x), ...))
}








##########################
#' @method find.clusters genlight
#' @export
#' @export
##########################
find.clusters.genlight <- function(x, clust = NULL, n.pca = NULL, n.clust = NULL,
                                   method = c("kmeans", "ward"),
                                   stat = c("BIC", "AIC", "WSS"),
                                   choose.n.clust = TRUE, 
                                   criterion = c("diffNgroup", "min","goesup", "smoothNgoesup", "goodfit"),
                                   max.n.clust = round(nInd(x)/10), n.iter = 1e5, n.start = 10,
                                   scale = FALSE, pca.select = c("nbEig","percVar"),
                                   perc.pca = NULL, glPca = NULL, ...){

    ## CHECKS ##
    if(!inherits(x, "genlight")) stop("x is not a genlight object.")
    stat <- match.arg(stat)
    pca.select <- match.arg(pca.select)


    ## SOME GENERAL VARIABLES ##
    N <- nInd(x)
    min.n.clust <- 2


    ## PERFORM PCA ##
    REDUCEDIM <- is.null(glPca)

    if(REDUCEDIM){ # if no glPca provided
        maxRank <- min(c(nInd(x), nLoc(x)))
        pcaX <- glPca(x, center = TRUE, scale = scale, nf=maxRank, loadings=FALSE, returnDotProd = FALSE, ...)
    } else {
        pcaX <- glPca
    }

    if(is.null(n.pca)){
        cumVar <- 100 * cumsum(pcaX$eig)/sum(pcaX$eig)
    }


    ## select the number of retained PC for PCA
    if(!REDUCEDIM){
        myCol <- rep(c("black", "lightgrey"), c(ncol(pcaX$scores),length(pcaX$eig)))
    } else {
        myCol <- "black"
    }

    if(is.null(n.pca) & pca.select=="nbEig"){
        plot(cumVar, xlab="Number of retained PCs", ylab="Cumulative variance (%)", main="Variance explained by PCA", col=myCol)
        cat("Choose the number PCs to retain (>=1): ")
        n.pca <- as.integer(readLines(con = getOption('adegenet.testcon'), n = 1))
    }

    if(is.null(perc.pca) & pca.select=="percVar"){
        plot(cumVar, xlab="Number of retained PCs", ylab="Cumulative variance (%)", main="Variance explained by PCA", col=myCol)
        cat("Choose the percentage of variance to retain (0-100): ")
        nperc.pca <- as.numeric(readLines(con = getOption('adegenet.testcon'), n = 1))
    }

    ## get n.pca from the % of variance to conserve
    if(!is.null(perc.pca)){
        n.pca <- min(which(cumVar >= perc.pca))
        if(perc.pca > 99.999) n.pca <- length(pcaX$eig)
        if(n.pca<1) n.pca <- 1
    }

    if(!REDUCEDIM){
        if(n.pca > ncol(pcaX$scores)) {
            n.pca <- ncol(pcaX$scores)
        }
    }


    ## convert PCA
    pcaX <- .glPca2dudi(pcaX)


    ## CALL DATA.FRAME METHOD
    res <- find.clusters(pcaX$li, clust=clust, n.pca=n.pca, n.clust=n.clust,
                         stat=stat, max.n.clust=max.n.clust, n.iter=n.iter, n.start=n.start,
                         choose.n.clust=choose.n.clust, method = method,
                         criterion=criterion, center=FALSE, scale=FALSE, dudi=pcaX)
    return(res)
} # end find.clusters.genlight










###################
## .find.sub.clusters
###################
.find.sub.clusters <- function(x, ...){

    ## GET ... ##
    myArgs <- list(...)
    if(!is.null(myArgs$quiet)){
        quiet <- myArgs$quiet
        myArgs$quiet <- NULL
    } else {
        quiet <- FALSE
    }

    clust <- myArgs$clust
    myArgs$clust <- NULL

    if(is.null(clust)) stop("clust is not provided")
    clust <- as.factor(clust)

    ## temp will store temporary resuts
    newFac <- character(length(clust))

    ## find sub clusters
    for(i in levels(clust)){
        if(!quiet) cat("\nLooking for sub-clusters in cluster",i,"\n")
        myArgs$x <- x[clust==i, , drop = FALSE]
        myArgs$max.n.clust <- nrow(x[clust==i, , drop = FALSE]) - 1
        temp <- do.call(find.clusters, myArgs)$grp
        levels(temp) <- paste(i, levels(temp), sep=".")
        newFac[clust==i] <- as.character(temp)
    }

    res <- list(stat=NA, grp=factor(newFac), size=as.integer(table(newFac)))

    return(res)
}





## Compute within sum of squares from a matrix 'x' and a factor 'f'
.compute.wss <- function(x, f) {
    x.group.mean <- apply(x, 2, tapply, f, mean)
    sum((x - x.group.mean[as.character(f),])^2)
}
