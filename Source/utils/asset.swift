import AVFoundation

public func getVideoAndDepthTrackAssociation(for asset: AVAsset) ->
  (videoTrack: CMPersistentTrackID?, depthTrack: CMPersistentTrackID?) {
  let depthTrack = asset.tracks.first(where: { isGrayscaleVideoTrack($0) })
  let videoTrack = asset.tracks.first(where: { isColorVideoTrack($0) })
  return (
    depthTrack: depthTrack?.trackID,
    videoTrack: videoTrack?.trackID
  )
}

// TODO: this is a super hacky way to check if a track is color or not
private func isGrayscaleVideoTrack(_ track: AVAssetTrack) -> Bool {
  guard
    track.mediaType == .video,
    let formatDescription = track.formatDescriptions.first,
    let ext = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: AnyObject],
    case .none = ext[kCVImageBufferYCbCrMatrixKey as String]
  else {
    return false
  }
  return true
}

private func isColorVideoTrack(_ track: AVAssetTrack) -> Bool {
  guard
    track.mediaType == .video,
    let formatDescription = track.formatDescriptions.first,
    let ext = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: AnyObject],
    case .some = ext[kCVImageBufferYCbCrMatrixKey as String]
  else {
    return false
  }
  return true
}
