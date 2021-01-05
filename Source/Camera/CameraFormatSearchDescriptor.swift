import AVFoundation
import ImageUtils

public struct CameraFormatSearchDescriptor {
    internal enum PixelFormatTypeRule {
        case any
        case oneOf([OSType])

        fileprivate func matches(format: AVCaptureDevice.Format) -> Bool {
            switch self {
            case .any:
                return true
            case let .oneOf(pixelFormatTypes):
                let pixelFormatType = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                return pixelFormatTypes.contains(pixelFormatType)
            }
        }
    }

    internal enum DimensionsRule {
        case any
        case equalTo(Size<Int>)
        case greaterThanOrEqualTo(Size<Int>)

        fileprivate func matches(format: AVCaptureDevice.Format) -> Bool {
            switch self {
            case .any:
                return true
            case let .equalTo(size):
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width == size.width && dimensions.height == size.height
            case let .greaterThanOrEqualTo(size):
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width >= size.width && dimensions.height >= size.height
            }
        }
    }

    internal enum FrameRateRule {
        case any
        case greaterThanOrEqualTo(Double)

        fileprivate func matches(format: AVCaptureDevice.Format) -> Bool {
            switch self {
            case .any:
                return true
            case let .greaterThanOrEqualTo(frameRate):
                guard
                    let maxFrameRateRange = format.videoSupportedFrameRateRanges.max(by: {
                        $0.maxFrameRate < $1.maxFrameRate
          })
                else {
                    return false
                }
                return maxFrameRateRange.maxFrameRate >= frameRate
            }
        }
    }

    internal enum SortRule {
        case maximizeFrameRate
        case maximizeDimensions

        fileprivate func sort(formats: [AVCaptureDevice.Format]) -> [AVCaptureDevice.Format] {
            return formats.sorted { a, b in
                switch self {
                case .maximizeFrameRate:
                    guard
                        let frameRateRangeA = a.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }),
                        let frameRateRangeB = b.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
                    else {
                        return false
                    }
                    return frameRateRangeA.maxFrameRate < frameRateRangeB.maxFrameRate
                case .maximizeDimensions:
                    return CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                        .width < CMVideoFormatDescriptionGetDimensions(b.formatDescription).width
                }
            }
        }
    }

    internal let depthPixelFormatTypeRule: PixelFormatTypeRule
    internal let depthDimensionsRule: DimensionsRule
    internal let videoDimensionsRule: DimensionsRule
    internal let frameRateRule: FrameRateRule
    internal let sortRule: SortRule
    internal let depthFormatSortRule: SortRule

    internal func search(formats: [AVCaptureDevice.Format]) -> SearchResult? {
        let filteredFormats = formats
            .filter { format in
                frameRateRule.matches(format: format)
                    && videoDimensionsRule.matches(format: format)
            }
            .filter { format in
                format.supportedDepthDataFormats.contains { depthFormat in
                    depthPixelFormatTypeRule.matches(format: depthFormat)
                        && depthDimensionsRule.matches(format: format)
                }
            }
        let sortedFormats = sortRule.sort(formats: filteredFormats)
        let bestFormatPairs = sortedFormats
            .map { format -> (AVCaptureDevice.Format, AVCaptureDevice.Format?) in
                let bestDepthFormat = depthFormatSortRule.sort(formats: format.supportedDepthDataFormats).last
                return (format, bestDepthFormat)
            }
            .compactMap { tuple -> (AVCaptureDevice.Format, AVCaptureDevice.Format)? in
                let (format, depthFormat) = tuple
                return (depthFormat != nil) ? (format, depthFormat!) : nil
            }
        guard let (format, depthFormat) = bestFormatPairs.last else {
            return nil
        }
        return SearchResult(format: format, depthDataFormat: depthFormat)
    }

    internal struct SearchResult {
        let format: AVCaptureDevice.Format
        let depthDataFormat: AVCaptureDevice.Format
    }
}
