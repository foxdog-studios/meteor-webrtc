# WebRTC Shim

@RTCPeerConnection = window.mozRTCPeerConnection \
    or window.PeerConnection \
    or window.RTCPeerConnection \
    or window.webkitPeerConnection00 \
    or window.webkitRTCPeerConnection

@IceCandidate = window.mozRTCIceCandidate or window.RTCIceCandidate

@SessionDescription = window.mozRTCSessionDescription \
    or window.RTCSessionDescription

@MediaStream = window.MediaStream or window.webkitMediaStream

navigator.getUserMedia = navigator.mozGetUserMedia \
    or navigator.getUserMedia \
    or navigator.webkitGetUserMedia \
    or navigator.msGetUserMedia

@URL = window.URL or window.webkitURL or window.msURL or window.oURL

