
enum {
	// Alignment of the image within the bounding rect (default is centered in both directions)
	DrawInsideAlignLeft = 1 << 0,
	DrawInsideAlignRight = 1 << 1,
	DrawInsideAlignTop = 1 << 2,
	DrawInsideAlignBottom = 1 << 3,
	// Set this flag to allow stretching the image to larger than its natural size (may induce ugly artifacts)
	DrawInsideAllowStretch = 1 << 4,
	// Set this flag to allow cropping the image in either direction. This will cause the image to be sized based on
	// its smaller side; for instance, you could set this flag to draw Flickr-style "square thumbnails" for non-square images.
	DrawInsideUniformFill = 1 << 5,
	// Set this flag to prevent automatically snapping the resulting image rect to whole pixels.
	DrawInsideNoPixelSnap = 1 << 6
};
typedef NSUInteger DrawInsideOptions;

// Resizes the given CGSize such that one of its sides equals the corresponding side in containingSize. If
// uniformFill is true, then the resulting size is guaranteed to be equal to or larger the targetSize, otherwise
// the resulting size is guaranteed to be smaller.
extern CGSize CGSizeResize(CGSize size, CGSize targetSize, bool uniformFill);

// Returns a rect with the given content size, positioned in the center of the given rect (which could be smaller)
extern CGRect CGRectCenteredInside(CGRect rect, CGSize contentSize);

// Positions the box of the given size inside the given rect with additional options.
extern CGRect CGRectPositionedInside(CGRect rect, CGSize contentSize, DrawInsideOptions options);

// Returns a rect at 0,0 with the given CGSize.
CG_INLINE CGRect
CGRectMakeWithSize(CGSize size) {
	CGRect rect;
	rect.origin.x = 0; rect.origin.y = 0;
	rect.size = size;
	return rect;
}

// Returns a point with its values rounded to the nearest integer.
extern CGPoint CGPointRounded(CGPoint point);

// Returns a size with its values rounded to the nearest integer.
extern CGSize CGSizeRounded(CGSize size);

// Returns a rect with its values rounded to the nearest integer.
extern CGRect CGRectRounded(CGRect rect);

extern bool CGSizeSmallerThanSize(CGSize size1, CGSize size2);
extern bool CGSizeLargerThanSize(CGSize size1, CGSize size2);