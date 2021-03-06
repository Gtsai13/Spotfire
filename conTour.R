# Inputs:
# x = numeric column (x coordinate) Real([DataTable].[${xcolumn}])
# y = numeric column (y coordinate) Real([DataTable].[${ycolumn}])
# z = numeric column (value to interpolate) Real([DataTable].[${zcolumn}])
# Optional inputs:
# smooth.scale = numeric scalar, controlling level of detail
# trimHull (0/1, controls whether to plot regions outside perimeter of points)
# clipToData (1) - truncate surface to original data limits?
# Output:
# contourTable

#------- Define function for clip contour by convex hull ---------------------------
InOut.contour.points = function(x.cont0, y.cont0, xref.vec, yref.vec){
  # Peter Shaw
  # Compares the set of x,y points (xref.vec,yref.vec) with the
  # (non-closed) contour defined by (x.cont0,y.cont0), to evaluate whether
  # the points are inside, or outside the contour. (The contour is first
  # closed upon itself to form a continuous loop).
  # Count the points. 
  N.cont = length(x.cont0)
  N.ref = length(xref.vec)
  # Close up the contours to create the working contour definitions.
  # First and last points will be the same. 
  x.cont = c( x.cont0, x.cont0[1] )
  y.cont = c( y.cont0, y.cont0[1] )
  u = 1:N.cont
  # Create pairs of vectors (vec1 and vec2) from reference points to
  # movements along the contour (defining pie-shaped sections thus angles)
  vec1.x = rep(1,N.ref) %o% x.cont[u] - xref.vec %o% rep(1,N.cont)
  vec2.x = rep(1,N.ref) %o% x.cont[u+1] - xref.vec %o% rep(1,N.cont)
  vec1.y = rep(1,N.ref) %o% y.cont[u] - yref.vec %o% rep(1,N.cont)
  vec2.y = rep(1,N.ref) %o% y.cont[u+1] - yref.vec %o% rep(1,N.cont)
  # Form vector cross product and dot products:
  Vec1xVec2 = vec1.x * vec2.y - vec2.x * vec1.y
  Vec1dVec2 = vec1.x * vec2.x + vec1.y * vec2.y
  # 4-quadrant atan (angles may be > 90 degrees)
  Ang = atan2( Vec1xVec2, Vec1dVec2 )
  # Form angle sums. These should be 0 or +/-1 to roundoff.
  # Sign tells which direction around you went. May be useful
  angle.sums = rowSums(Ang) / (2 * pi)
  # Round these to a reasonable roundoff and take abs
  return( round( abs( angle.sums ) * 1000 ) / 1000 )
}

#-----------------------------------------------------------------------------------------------------------------------
if(is.null(smooth.scale)) smooth.scale = 0.5
if(is.null(trimHull)) trimHull = 1
if(is.null(clipToData)) clipToData = 1

# ------------ Make null objects -------------------
contourTable = data.frame(
  segment = character(0),
  level = character(0),
  x = numeric(0),
  y = numeric(0),
  z = numeric(0),
  order = numeric(0),
  stringsAsFactors = F
)

library(RinR)
errorCondition = FALSE
if( length(x)==0 | length(y)==0 | length(z)==0 ) errorCondition=TRUE

if( !errorCondition ) {
  #xydata.pred.in = data.frame( ID=ID, x=x, y=y, z.orig=z, stringsAsFactors=F ) # for prediction.
  #bad = is.na(x) | is.na(x)
  #xydata.pred.in = xydata.pred.in[ !bad, ]
  xyzdata = data.frame( x=x, y=y, z=z )
  bad = is.na(x) | is.na(x) | is.na(z)
  xyzdata = xyzdata[ !bad, ]
  #xyzdata.lo = try(loess(z ~ x * y, data=xyzdata, span=smooth.scale, na.action=na.exclude))
  xyzdata.lo = REvaluate(
    expr = { try(loess(z~x*y, data=data, span=span, na.action=na.exclude)) },
    data = list(data=xyzdata, span=smooth.scale)
  )
  if(class(xyzdata.lo)=='Error') errorCondition=TRUE #2nd way to get here
  if(!errorCondition){
    xvec = seq(from=min(x,na.rm=T), to=max(x,na.rm=T), length=200) #Lon.vec
    yvec = seq(from=min(y,na.rm=T), to=max(y,na.rm=T), length=200) #Lat.vec
    xyzdata.lo.pred = REvaluate(
      expr = { predict( xyzdata.lo, newdata=expand.grid(x=xvec, y=yvec)) },
      data = list(xyzdata.lo=xyzdata.lo, xvec=xvec, yvec=yvec)
    )
    x.mtx = xvec %o% rep(1,length(yvec))
    y.mtx = rep(1, length(xvec)) %o% yvec
    # calculate convex hull
    points.chull = REvaluate(
      expr = { chull(xyzdata$x, xyzdata$y) }, #calculate convex hull of data points
      data = list(xyzdata=xyzdata)
    )
    if( trimHull==1 ) { # Possibly trim points:
      mtx.inout.vec = InOut.contour.points(
        x.cont0 = xyzdata$x[points.chull],
        y.cont0 = xyzdata$y[points.chull],
        xref.vec = as.numeric(x.mtx),
        yref.vec = as.numeric(y.mtx)
      )
      xyzdata.lo.pred[ mtx.inout.vec==0 ] = NA
    }
    if( clipToData==1 ) { # Possibly limit surface to original data limits.
      xyzdata.lo.pred = pmin(xyzdata.lo.pred,max(z,na.rm=T))
      xyzdata.lo.pred = pmax(xyzdata.lo.pred,min(z,na.rm=T))
    }
  }
} # end of last if(!errorCondition)

if( !errorCondition ) { # break things up
  # calculate convex hull
  # points.chull = REvaluate(
  # expr = {chull(x, y)}, #calculate convex hull of data points
  # data = list(x=x, y=y)
  # )
  # x.cont0 = xyzdata$x[points.chull],
  # y.cont0 = xyzdata$y[points.chull],
  # Set up data frame with the chull
  
  points.chull.closed = c(points.chull,points.chull[1])
  x.chull = xyzdata$x[points.chull.closed]
  y.chull = xyzdata$y[points.chull.closed]
  N = length(points.chull.closed)
  borderTable = data.frame(
    segment = rep('border', N),
    level = rep('border', N),
    x = x.chull + 0.0001*runif(n=N, min = -1, max=1), #helps SF ordering
    y = y.chull + 0.0001*runif(n=N, min = -1, max=1),
    z = rep(NA, N),
    stringsAsFactors = F
  )
  
  # Minor Contours
  contourList = REvaluate(
    expr = { contourLines(x=x, y=y, z=z, levels=levels) },
    data = list(x=xvec, y=yvec, z=xyzdata.lo.pred, levels=pretty(xyzdata.lo.pred, 20))
  )
  if( length(contourList) > 0 ) 
    contourTable.pure = do.call(rbind,
                                lapply(X=1:length(contourList),
                                       FUN=function(iseg,contourList){
                                         this.seg=contourList[[iseg]]
                                         N=length(this.seg$x)
                                         table.part = data.frame(
                                           segment = rep( paste(this.seg$level, iseg, sep='-'), N ),
                                           level = rep("Minor", N),
                                           x = this.seg$x,
                                           y = this.seg$y,
                                           z = rep(this.seg$level, N),
                                           stringsAsFactors = F
                                         )
                                       }, contourList = contourList
                                )
    )
  contourTable.minor = rbind(borderTable, contourTable.pure)
} else {
  contourTable.minor = borderTable
}
# Major Contours
contourList = REvaluate(
  expr = { contourLines(x=x, y=y, z=z, levels=levels) },
  data = list(x=xvec, y=yvec, z=xyzdata.lo.pred, levels=pretty(xyzdata.lo.pred, 5))
)
contourTable.pure = do.call(rbind,
                            if(length(contourList)>0){
                              lapply(X=1:length(contourList),
                                     FUN=function(iseg,contourList){
                                       this.seg=contourList[[iseg]]
                                       N=length(this.seg$x)
                                       table.part = data.frame(
                                         segment = rep( paste(this.seg$level,iseg, sep='-'), N),
                                         level = rep("Major", N),
                                         x = this.seg$x,
                                         y = this.seg$y,
                                         z = rep(this.seg$level, N),
                                         stringsAsFactors = F
                                       )
                                     }, contourList = contourList
                              )
)
contourTable.pure$x = contourTable.pure$x + 0.0001*runif(nrow(contourTable.pure),min=-1,max=1)
contourTable.pure$y = contourTable.pure$y + 0.0001*runif(nrow(contourTable.pure),min=-1,max=1)
contourTable = rbind(contourTable.minor, contourTable.pure)
                            } else {
                              contourTable = contourTable.minor
                            }
contourTable$order = 1:nrow(contourTable)
} 
# end of errorCondition
# One last check: if incoming z is constant, no contours will be present.
# Spotfire doesn't like all-missings in the contourTable, so replace the NAs in the border with mean of z if present.
if(all(is.na(contourTable$z))) {
  contourTable$z = mean(z,na.rm=T) # will be NaN if all of z is NA
}
