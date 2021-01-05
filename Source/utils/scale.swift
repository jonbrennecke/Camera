import CoreGraphics
import Foundation

func scaleForResizing(_ originalSize: CGSize, to size: CGSize, resizeMode: ResizeMode) -> CGFloat {
    let aspectRatio = originalSize.width / originalSize.height
    let scaleHeight = (size.height * aspectRatio) / originalSize.width
    let scaleWidth = size.width / originalSize.width
    switch resizeMode {
    case .scaleAspectFill:
        return (originalSize.height * scaleWidth) < size.height
            ? scaleHeight
            : scaleWidth
    case .scaleAspectWidth:
        return scaleWidth
    case .scaleAspectHeight:
        return scaleHeight
    }
}
