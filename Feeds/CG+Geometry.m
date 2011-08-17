#import "CG+Geometry.h"

CGSize CGSizeResize(CGSize size, CGSize targetSize, bool uniformFill) {

	if (CGSizeEqualToSize(size, targetSize))
		return size; // boundary
	
	CGFloat aspectRatio = size.width / size.height;
	CGFloat targetRatio = targetSize.width / targetSize.height;

	// this makes sense when you draw out some samples on graph paper.
	bool matchWidth = uniformFill ? aspectRatio < targetRatio : aspectRatio > targetRatio;
	
	if (matchWidth)
		return CGSizeMake(targetSize.width, targetSize.width / aspectRatio);
	else
		return CGSizeMake(targetSize.height * aspectRatio, targetSize.height);
}

CGRect CGRectCenteredInside(CGRect rect, CGSize contentSize) {
	
	return (CGRect){
		.origin.x = CGRectGetMinX(rect) + round((CGRectGetWidth(rect) - contentSize.width) / 2), 
		.origin.y = CGRectGetMinY(rect) + round((CGRectGetHeight(rect) - contentSize.height) / 2),
		.size = contentSize
	};	
}

CGRect CGRectPositionedInside(CGRect rect, CGSize contentSize, DrawInsideOptions options) {

	BOOL smaller = CGSizeSmallerThanSize(contentSize, rect.size);
	BOOL larger = CGSizeLargerThanSize(contentSize, rect.size);
	
	// Does the bounding size (almost) exactly match the target size? If so, just return the bounding rect
	if (!smaller && !larger)
		return rect;
	
	// We'll need to resize ourself first, only if we're larger than the target rect
	// or if we're smaller but are allowed to stretch.
	if (larger || (options & DrawInsideAllowStretch) > 0)
		contentSize = CGSizeResize(contentSize, rect.size, (options & DrawInsideUniformFill) > 0);
	
	CGRect centeredRect = CGRectCenteredInside(rect, contentSize);
	
	if ((options & DrawInsideNoPixelSnap) == 0)
		centeredRect = CGRectRounded(centeredRect);
	
	if ((options & DrawInsideAlignLeft) > 0)
		centeredRect.origin.x = CGRectGetMinX(rect);
	else if ((options & DrawInsideAlignRight) > 0)
		centeredRect.origin.x = CGRectGetMaxX(rect) - contentSize.width;
	
	if ((options & DrawInsideAlignTop) > 0)
		centeredRect.origin.y = CGRectGetMinY(rect);
	else if ((options & DrawInsideAlignBottom) > 0)
		centeredRect.origin.y = CGRectGetMaxY(rect) - contentSize.height;
	
	return centeredRect;
}


CGPoint CGPointRounded(CGPoint point) {
	return CGPointMake(roundf(point.x), roundf(point.y));
}

CGSize CGSizeRounded(CGSize size) {
	return CGSizeMake(roundf(size.width), roundf(size.height));
}

CGRect CGRectRounded(CGRect r) {
	return CGRectMake(roundf(r.origin.x), roundf(r.origin.y), roundf(r.size.width), roundf(r.size.height));
}

bool CGSizeSmallerThanSize(CGSize size1, CGSize size2) {
	// 0.001 is to accomodate for float rounding errors
	return (size1.width < size2.width - 0.001 && size1.height <= size2.height + 0.001) ||
		(size1.height < size2.height - 0.001 && size1.width <= size2.width + 0.001);
}

bool CGSizeLargerThanSize(CGSize size1, CGSize size2) {
	// 0.001 is to accomodate for float rounding errors
	return size1.width > size2.width + 0.001 || size1.height > size2.height + 0.001;
}
