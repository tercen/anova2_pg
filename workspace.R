library(tercen)
library(dplyr)

# Set appropriate options
# options("tercen.serviceUri"="http://tercen:5400/api/v1/")
# options("tercen.workflowId"= "e3a373ea9ad78b1a5d42b21cac0076cc")
# options("tercen.stepId"= "220b6a01-011f-4ba9-b43d-c0331f0a637a")
# options("tercen.username"= "admin")
# options("tercen.password"= "admin")

do.anova = function(df, interact = FALSE){
  result      <- NULL
  aModelError <- FALSE
  
  if (interact) {
    formula <- ".y ~ .group.colors1 * .group.colors2"
    aLm     <- try(lm(formula, data=df), silent = TRUE)
    if(!inherits(aLm, 'try-error')) {
      anAnova <- try(anova(aLm), silent = TRUE)
      if (!inherits(anAnova, "try-error")) {
        pFactor1 <- anAnova['Pr(>F)'][1,]
        pFactor2 <- anAnova['Pr(>F)'][2,]
        pFactor3 <- anAnova['Pr(>F)'][3,]
        logp1    <- -log10(pFactor1)
        logp2    <- -log10(pFactor2)
        logp3    <- -log10(pFactor3)
      } else {
        aModelError <- TRUE
      }
    } else {
      aModelError <- TRUE
    }
    if (aModelError) {  
      pFactor1 <- pFactor2 <- pFactor3 <- logp1 <- logp2 <- logp3 <- NaN
    }
    result <- data.frame(.ri      = df$.ri[1], 
                         .ci      = df$.ci[1],
                         p1       = pFactor1,
                         p2       = pFactor2, 
                         p1.2     = pFactor3, 
                         logp1    = logp1, 
                         logp2    = logp2, 
                         logp1.2  = logp3)
  } else {
    formula <- ".y ~ .group.colors1 + .group.colors2"
    aLm     <- try(lm(formula, data=df), silent = TRUE)
    if(!inherits(aLm, 'try-error')) {
      anAnova <- try(anova(aLm), silent = TRUE)
      if (!inherits(anAnova, "try-error")) {
        pFactor1 <- anAnova['Pr(>F)'][1,]
        pFactor2 <- anAnova['Pr(>F)'][2,]
        logp1    <- -log10(pFactor1)
        logp2    <- -log10(pFactor2)
      } else {
        aModelError <- TRUE
      }
    } else {
      aModelError <- TRUE
    }
    if (aModelError) {  
      pFactor1 <- pFactor2 <- logp1 <- logp2 <- NaN
    }
    result <- data.frame(.ri      = df$.ri[1], 
                         .ci      = df$.ci[1],
                         p1       = pFactor1,
                         p2       = pFactor2, 
                         logp1    = logp1, 
                         logp2    = logp2)
  }
  result
}

ctx = tercenCtx()

if (length(ctx$colors) != 2) stop("Need exactly two data colors to define the grouping factors.")

Interaction   <- ifelse(is.null(ctx$op.value('Include interaction')), FALSE, as.logical(ctx$op.value('Include interaction')))
groupingType1 <- ifelse(is.null(ctx$op.value('Grouping Variable 1')), 'categorical', ctx$op.value('Grouping Variable 1'))
groupingType2 <- ifelse(is.null(ctx$op.value('Grouping Variable 2')), 'categorical', ctx$op.value('Grouping Variable 2'))

data <- ctx %>% 
  select(.ci, .ri, .y) %>%
  mutate(.group.colors1 = ctx$select(ctx$colors[[1]]) %>% pull()) %>%
  mutate(.group.colors2 = ctx$select(ctx$colors[[2]]) %>% pull())

if (groupingType1 == 'categorical'){
  data <- data %>% mutate(.group.colors1 = as.factor(.group.colors1))
} else {
  if (!is.numeric(data %>% pull(.group.colors1))){
    stop("Factor 1 can not be used as a numeric factor")
  }
}

if (groupingType2 == 'categorical'){
  data <- data %>% mutate(.group.colors2 = as.factor(.group.colors2))
} else {
  if (!is.numeric(data %>% pull(.group.colors2))){
    stop("Factor 2 can not be used as a numeric factor")
  }
}

data %>%
  group_by(.ci, .ri) %>%
  do(do.anova(., Interaction)) %>%
  ctx$addNamespace() %>%
  ctx$save()

