import CommonCrypto
import Foundation
import Network
import Security
import zlib

struct HSNativeMTProtoEndpoint: Equatable {
    let host: String
    let port: UInt16

    var displayName: String {
        "\(host):\(port)"
    }
}

struct HSNativeMTProtoConfiguration: Equatable {
    let apiID: Int32
    let apiHash: String
    let layer: Int32
    let datacenterID: Int
    let host: String
    let port: UInt16
    let deviceModel: String
    let fallbackEndpoints: [HSNativeMTProtoEndpoint]

    init(
        apiID: Int32,
        apiHash: String,
        layer: Int32,
        datacenterID: Int,
        host: String,
        port: UInt16,
        deviceModel: String,
        fallbackEndpoints: [HSNativeMTProtoEndpoint] = []
    ) {
        self.apiID = apiID
        self.apiHash = apiHash
        self.layer = layer
        self.datacenterID = datacenterID
        self.host = host
        self.port = port
        self.deviceModel = deviceModel
        self.fallbackEndpoints = fallbackEndpoints
    }

    var endpoints: [HSNativeMTProtoEndpoint] {
        var seen = Set<String>()
        return ([HSNativeMTProtoEndpoint(host: host, port: port)] + fallbackEndpoints).filter { endpoint in
            seen.insert(endpoint.displayName).inserted
        }
    }

    static var production: HSNativeMTProtoConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let primaryHost = environment["HS_NATIVE_MTPROTO_HOST"] ?? "43.134.228.34"
        let primaryPort = parsePort(environment["HS_NATIVE_MTPROTO_PORT"]) ?? 11443
        let fallbackEndpoints = parseEndpoints(environment["HS_NATIVE_MTPROTO_FALLBACKS"]) ?? [
            HSNativeMTProtoEndpoint(host: "124.220.11.177", port: 5222)
        ]

        return HSNativeMTProtoConfiguration(
            apiID: 24547280,
            apiHash: "3ae3c1b4aa1af9954e28ac446ec6dbf2",
            layer: 223,
            datacenterID: 1,
            host: primaryHost,
            port: primaryPort,
            deviceModel: "iPhone",
            fallbackEndpoints: fallbackEndpoints
        )
    }

    private static func parsePort(_ value: String?) -> UInt16? {
        guard let value, let port = UInt16(value), port > 0 else {
            return nil
        }
        return port
    }

    private static func parseEndpoints(_ value: String?) -> [HSNativeMTProtoEndpoint]? {
        guard let value else {
            return nil
        }
        let endpoints = value
            .split(separator: ",")
            .compactMap { parseEndpoint(String($0)) }
        return endpoints.isEmpty ? nil : endpoints
    }

    private static func parseEndpoint(_ value: String) -> HSNativeMTProtoEndpoint? {
        let parts = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let port = UInt16(parts[1]), port > 0 else {
            return nil
        }
        let host = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? nil : HSNativeMTProtoEndpoint(host: host, port: port)
    }
}

enum HSNativeMTProtoError: LocalizedError {
    case randomBytesFailed(OSStatus)
    case connectionFailed(String)
    case timedOut
    case malformedPacket(String)
    case serverDHParamsPending(serverTime: Int32, fingerprint: Int64)
    case encryptedTransportPending(method: String, authKeyID: Int64, serverSalt: Int64)

    var serverCode: String {
        switch self {
        case .serverDHParamsPending:
            return "HS_NATIVE_MTPROTO_CLIENT_DH_PENDING"
        case .encryptedTransportPending:
            return "HS_NATIVE_MTPROTO_AUTHKEY_PENDING"
        case .connectionFailed, .timedOut:
            return "HS_NATIVE_MTPROTO_CONNECT_FAILED"
        case .malformedPacket, .randomBytesFailed:
            return "HS_NATIVE_MTPROTO_PROTOCOL_ERROR"
        }
    }

    var errorDescription: String? {
        switch self {
        case .randomBytesFailed(let status):
            return "生成 MTProto nonce 失败：\(status)。"
        case .connectionFailed(let message):
            return "无法连接 HSgram MTProto 服务：\(message)"
        case .timedOut:
            return "连接 HSgram MTProto 服务超时。"
        case .malformedPacket(let message):
            return "HSgram MTProto 服务返回数据无法解析：\(message)"
        case .serverDHParamsPending(let serverTime, let fingerprint):
            return "已完成 HSgram MTProto req_DH_params，并解析到 server_DH_inner_data；下一步需要计算 g_b/auth_key 后提交 set_client_DH_params。server_time=\(serverTime)，fingerprint=\(fingerprint)。"
        case .encryptedTransportPending(let method, let authKeyID, let serverSalt):
            return "已完成 HSgram MTProto auth_key DH 握手；下一步需要用 auth_key_id=\(authKeyID)、server_salt=\(serverSalt) 加密发送 \(method)。"
        }
    }
}

enum HSNativeMTProtoSchema {
    static let reqPqMulti: UInt32 = 0xbe7e8ef1
    static let resPq: UInt32 = 0x05162463
    static let vector: UInt32 = 0x1cb5c415
    static let pQInnerData: UInt32 = 0x83c95aec
    static let reqDHParams: UInt32 = 0xd712e4be
    static let serverDHParamsOk: UInt32 = 0xd0e8075c
    static let serverDHParamsFail: UInt32 = 0x79cb045d
    static let serverDHInnerData: UInt32 = 0xb5890dba
    static let clientDHInnerData: UInt32 = 0x6643b654
    static let setClientDHParams: UInt32 = 0xf5045f1f
    static let dhGenOk: UInt32 = 0x3bcbf734
    static let dhGenRetry: UInt32 = 0x46dc1fb9
    static let dhGenFail: UInt32 = 0xa69dae02

    static let codeSettings: UInt32 = 0xad253d78
    static let emailVerificationCode: UInt32 = 0x922e55a9
    static let authSendCode: UInt32 = 0xa677244f
    static let authSignInEmail: UInt32 = 0x8d52a951
    static let authSignInCode: UInt32 = 0xbcd51581
    static let authSignUp: UInt32 = 0xaac7b717
    static let authSignUpLegacy: UInt32 = 0x80eee427
    static let photosUpdateProfilePhoto: UInt32 = 0x09e82039
    static let photosUploadProfilePhoto: UInt32 = 0x89f30f69
    static let photosPhoto: UInt32 = 0x20212ca8
    static let inputPhotoEmpty: UInt32 = 0x1cd7bf0d
    static let authCheckPassword: UInt32 = 0xd18b4d16
    static let authRequestPasswordRecovery: UInt32 = 0xd897bc66
    static let authRecoverPassword: UInt32 = 0x37096c70
    static let accountGetPassword: UInt32 = 0x548a30f5
    static let accountUpdatePasswordSettings: UInt32 = 0xa59b102f
    static let accountConfirmPasswordEmail: UInt32 = 0x8fdf1920
    static let accountResendPasswordEmail: UInt32 = 0x7a7f2a15
    static let accountCancelPasswordEmail: UInt32 = 0xc1cbd5b6
    static let accountDeleteAccount: UInt32 = 0xa2c0cf74
    static let accountUpdateProfile: UInt32 = 0x78515775
    static let accountUpdateUsername: UInt32 = 0x3e0bdd7c
    static let usersGetFullUser: UInt32 = 0xb60f5918
    static let usersUserFull: UInt32 = 0x3b6d152e
    static let userFull: UInt32 = 0xa02bc13e
    static let accountGetAuthorizations: UInt32 = 0xe320c158
    static let accountResetAuthorization: UInt32 = 0xdf77f3bc
    static let accountGetPrivacy: UInt32 = 0xdadbc950
    static let accountSetPrivacy: UInt32 = 0xc9f81ce8
    static let accountGetNotifySettings: UInt32 = 0x12b3ad31
    static let accountUpdateNotifySettings: UInt32 = 0x84be5b93
    static let accountReportPeer: UInt32 = 0xc5ba3d86
    static let accountRegisterDevice: UInt32 = 0xec86017a
    static let accountUnregisterDevice: UInt32 = 0x6a0d3206
    static let accountAuthorizations: UInt32 = 0x4bff8ea0
    static let accountPrivacyRules: UInt32 = 0x50a04e45
    static let authorization: UInt32 = 0xad01d61d
    static let accountPassword: UInt32 = 0x957b50fb
    static let passwordKdfAlgoUnknown: UInt32 = 0xd45ab096
    static let passwordKdfAlgoModPow: UInt32 = 0x3a912d4a
    static let securePasswordKdfAlgoUnknown: UInt32 = 0x004a8537
    static let securePasswordKdfAlgoPBKDF2: UInt32 = 0xbbf2dda0
    static let securePasswordKdfAlgoSHA512: UInt32 = 0x86471d92
    static let inputCheckPasswordEmpty: UInt32 = 0x9880f658
    static let inputCheckPasswordSRP: UInt32 = 0xd27ff082
    static let accountPasswordInputSettings: UInt32 = 0xc23727c9
    static let initConnection: UInt32 = 0xc1cd5ea9
    static let invokeWithLayer: UInt32 = 0xda9b0d0d
    static let rpcResult: UInt32 = 0xf35c6d01
    static let rpcError: UInt32 = 0x2144ca19
    static let newSessionCreated: UInt32 = 0x9ec20908
    static let msgContainer: UInt32 = 0x73f1f8dc
    static let msgsAck: UInt32 = 0x62d6b459
    static let badMsgNotification: UInt32 = 0xa7eff811
    static let badServerSalt: UInt32 = 0xedab447b
    static let gzipPacked: UInt32 = 0x3072cfa1
    static let authSentCode: UInt32 = 0x5e002502
    static let authSentCodeSuccess: UInt32 = 0x2390fe44
    static let authSentCodePaymentRequired: UInt32 = 0xe0955a3c
    static let authSentCodePaymentRequiredV2: UInt32 = 0xd7a2fcf9
    static let authSentCodePaymentRequiredV3: UInt32 = 0xd7cef980
    static let authSentCodeTypeApp: UInt32 = 0x3dbb5986
    static let authSentCodeTypeSms: UInt32 = 0xc000bba2
    static let authSentCodeTypeCall: UInt32 = 0x5353e5a7
    static let authSentCodeTypeEmailCode: UInt32 = 0xf450f59b
    static let authSentCodeTypeEmailCodeV2: UInt32 = 0x5a159841
    static let authAuthorization: UInt32 = 0x2ea2c0d4
    static let authAuthorizationSignUpRequired: UInt32 = 0x44747e9a
    static let helpTermsOfService: UInt32 = 0x780a0310
    static let dataJSON: UInt32 = 0x7d748d04
    static let authPasswordRecovery: UInt32 = 0x137948a5
    static let updatesGetState: UInt32 = 0xedd4882a
    static let updatesGetDifference: UInt32 = 0x19c2f763
    static let messagesGetDialogs: UInt32 = 0xa0f4cb4f
    static let messagesGetPeerDialogs: UInt32 = 0xe470bcfd
    static let messagesGetHistory: UInt32 = 0x4423e6c5
    static let messagesReadHistory: UInt32 = 0x0e306d3a
    static let messagesMarkDialogUnread: UInt32 = 0x8c5006f8
    static let messagesGetDialogFilters: UInt32 = 0xefd48c89
    static let messagesUpdateDialogFilter: UInt32 = 0x1ad4a04a
    static let messagesUpdateDialogFiltersOrder: UInt32 = 0xc563c1e4
    static let messagesToggleDialogFilterTags: UInt32 = 0xfd2dda49
    static let messagesToggleDialogPin: UInt32 = 0xa731e257
    static let messagesReorderPinnedDialogs: UInt32 = 0x3b1adf37
    static let foldersEditPeerFolders: UInt32 = 0x6847d0ab
    static let messagesSendMessage: UInt32 = 0x545cd15a
    static let messagesSendMedia: UInt32 = 0xa550cd78
    static let messagesSetTyping: UInt32 = 0x58943ee2
    static let messagesForwardMessages: UInt32 = 0xbb9fa475
    static let messagesSearchGlobal: UInt32 = 0x4bc6589a
    static let messagesSearch: UInt32 = 0x29ee847a
    static let messagesGetSearchCounters: UInt32 = 0x1bbcf300
    static let messagesEditMessage: UInt32 = 0x51e842e1
    static let messagesDeleteMessages: UInt32 = 0xe58e95d2
    static let messagesDeleteHistory: UInt32 = 0xb08f922a
    static let messagesSaveDraft: UInt32 = 0x54ae308e
    static let messagesGetWebPagePreview: UInt32 = 0x570d6f6f
    static let messagesWebPagePreview: UInt32 = 0xb53e8b21
    static let messagesGetAllDrafts: UInt32 = 0x6a3f8d65
    static let messagesSendReaction: UInt32 = 0xd30d78d4
    static let messagesGetAllStickers: UInt32 = 0xb8a0a1a8
    static let messagesGetFeaturedStickers: UInt32 = 0x64780b14
    static let messagesGetAvailableReactions: UInt32 = 0x18dea0ac
    static let messagesEditChatAbout: UInt32 = 0xdef60797
    static let messagesGetFullChat: UInt32 = 0xaeb00b34
    static let messagesUpdatePinnedMessage: UInt32 = 0xd2aaf7ec
    static let messagesExportChatInvite: UInt32 = 0xa455de90
    static let messagesAffectedMessages: UInt32 = 0x84d19185
    static let messagesAffectedHistory: UInt32 = 0xb45c69d1
    static let messagesSearchCounter: UInt32 = 0xe844ebff
    static let messagesInvitedUsers: UInt32 = 0x7f5defa6
    static let messagesAllStickers: UInt32 = 0xcdbbcebb
    static let messagesAllStickersNotModified: UInt32 = 0xe86602c3
    static let messagesFeaturedStickers: UInt32 = 0xbe382906
    static let messagesFeaturedStickersNotModified: UInt32 = 0xc6dc0c66
    static let messagesAvailableReactions: UInt32 = 0x768e3aad
    static let messagesAvailableReactionsNotModified: UInt32 = 0x9f071957
    static let availableReaction: UInt32 = 0xc077ec01
    static let contactsGetContacts: UInt32 = 0x5dd69e12
    static let contactsGetBlocked: UInt32 = 0x9a868f80
    static let contactsSearch: UInt32 = 0x11f812d8
    static let contactsResolveUsername: UInt32 = 0x725afbbc
    static let contactsResolvePhone: UInt32 = 0x8af94344
    static let contactsAddContact: UInt32 = 0xd9ba2e54
    static let contactsDeleteContacts: UInt32 = 0x096a0e00
    static let contactsBlock: UInt32 = 0x2e2e8734
    static let contactsUnblock: UInt32 = 0xb550d328
    static let contactsAcceptContact: UInt32 = 0xf831a20f
    static let contactsRequestContact: UInt32 = 0xf6f360ce
    static let contactsDeclineContact: UInt32 = 0x46b0174e
    static let contactsContacts: UInt32 = 0xeae87e42
    static let contactsContactsNotModified: UInt32 = 0xb74ba9d2
    static let contactsBlocked: UInt32 = 0x0ade1591
    static let contactsBlockedSlice: UInt32 = 0xe1664194
    static let contactsFound: UInt32 = 0xb3134d9d
    static let contactsResolvedPeer: UInt32 = 0x7f077ad9
    static let contact: UInt32 = 0x145ade0b
    static let peerBlocked: UInt32 = 0xe8fd8014
    static let boolFalse: UInt32 = 0xbc799737
    static let boolTrue: UInt32 = 0x997275b5
    static let sendMessageCancelAction: UInt32 = 0xfd5ec8f5
    static let sendMessageRecordAudioAction: UInt32 = 0xd52f73f7
    static let sendMessageRecordRoundAction: UInt32 = 0x88f27fbc
    static let sendMessageRecordVideoAction: UInt32 = 0xa187d66f
    static let sendMessageTypingAction: UInt32 = 0x16bf744e
    static let sendMessageUploadAudioAction: UInt32 = 0xf351d7ab
    static let sendMessageUploadDocumentAction: UInt32 = 0xaa0cd9e4
    static let sendMessageUploadPhotoAction: UInt32 = 0xd1d34a26
    static let sendMessageUploadRoundAction: UInt32 = 0x243e1c66
    static let sendMessageUploadVideoAction: UInt32 = 0xe9763aec
    static let sendMessageChooseStickerAction: UInt32 = 0xb05ac6b1
    static let inputPeerEmpty: UInt32 = 0x7f3b18ea
    static let inputPeerSelf: UInt32 = 0x7da07ec9
    static let inputPeerChat: UInt32 = 0x35a95cb9
    static let inputPeerUser: UInt32 = 0xdde8a54c
    static let inputPeerChannel: UInt32 = 0x27bcbbfc
    static let inputDialogPeer: UInt32 = 0xfcaafeb7
    static let inputDialogPeerFolder: UInt32 = 0x64600527
    static let inputFolderPeer: UInt32 = 0xfbd2c296
    static let dialogPeer: UInt32 = 0xe56dbf05
    static let dialogPeerFolder: UInt32 = 0x514519e2
    static let folderPeer: UInt32 = 0xe9baa668
    static let inputUserSelf: UInt32 = 0xf7c1b13f
    static let inputUser: UInt32 = 0xf21158c6
    static let inputNotifyPeer: UInt32 = 0xb8bc5b0c
    static let inputNotifyUsers: UInt32 = 0x193b4417
    static let inputNotifyChats: UInt32 = 0x4a95e84e
    static let inputNotifyBroadcasts: UInt32 = 0xb1db7c7e
    static let inputPeerNotifySettings: UInt32 = 0xcacb6ae2
    static let inputReportReasonSpam: UInt32 = 0x58dbcab8
    static let inputReportReasonViolence: UInt32 = 0x1e22c78d
    static let inputReportReasonPornography: UInt32 = 0x2e59d922
    static let inputReportReasonChildAbuse: UInt32 = 0xadf44ee3
    static let inputReportReasonOther: UInt32 = 0xc1e4a2b1
    static let inputReportReasonCopyright: UInt32 = 0x9b89f93a
    static let inputReportReasonGeoIrrelevant: UInt32 = 0xdbd4feed
    static let inputReportReasonFake: UInt32 = 0xf5ddd6e7
    static let inputReportReasonIllegalDrugs: UInt32 = 0x0a8eb2be
    static let inputReportReasonPersonalDetails: UInt32 = 0x9ec7863d
    static let peerSettings: UInt32 = 0xf47741f7
    static let inputPrivacyKeyAbout: UInt32 = 0x3823cc40
    static let inputPrivacyKeyChatInvite: UInt32 = 0xbdfb0426
    static let inputPrivacyKeyForwards: UInt32 = 0xa4dd4c08
    static let inputPrivacyKeyPhoneCall: UInt32 = 0xfabadc5f
    static let inputPrivacyKeyPhoneNumber: UInt32 = 0x0352dafa
    static let inputPrivacyKeyProfilePhoto: UInt32 = 0x5719bacc
    static let inputPrivacyKeyStatusTimestamp: UInt32 = 0x4f96cb18
    static let inputPrivacyValueAllowAll: UInt32 = 0x184b35ce
    static let inputPrivacyValueAllowContacts: UInt32 = 0x0d09e07b
    static let inputPrivacyValueAllowUsers: UInt32 = 0x131cc67f
    static let inputPrivacyValueDisallowUsers: UInt32 = 0x90110467
    static let inputPrivacyValueDisallowAll: UInt32 = 0xd66b66c9
    static let inputPrivacyValueAllowChatParticipants: UInt32 = 0x840649cf
    static let inputPrivacyValueDisallowChatParticipants: UInt32 = 0xe94f0f86
    static let textWithEntities: UInt32 = 0x751f3146
    static let dialogFilter: UInt32 = 0xaa472651
    static let dialogFilterChatlist: UInt32 = 0x96537bd7
    static let dialogFilterDefault: UInt32 = 0x363293ae
    static let messagesDialogFilters: UInt32 = 0x2ad93719
    static let inputReplyToMessage: UInt32 = 0x869fbe10
    static let inputMessagesFilterEmpty: UInt32 = 0x57e2f66c
    static let inputMessagesFilterPhotoVideo: UInt32 = 0x56e9f0e4
    static let inputMessagesFilterDocument: UInt32 = 0x9eddf188
    static let inputMessagesFilterUrl: UInt32 = 0x7ef0dd87
    static let inputMessagesFilterGif: UInt32 = 0xffc86587
    static let inputMessagesFilterMusic: UInt32 = 0x3751b49e
    static let inputMessagesFilterRoundVoice: UInt32 = 0x7a7c17a4
    static let reactionEmoji: UInt32 = 0x1b2286b8
    static let uploadSaveFilePart: UInt32 = 0xb304a621
    static let uploadSaveBigFilePart: UInt32 = 0xde7b673d
    static let uploadGetFile: UInt32 = 0xbe5335be
    static let uploadFile: UInt32 = 0x096a18d5
    static let uploadFileCdnRedirect: UInt32 = 0xf18cda44
    static let inputFile: UInt32 = 0xf52ff27f
    static let inputFileBig: UInt32 = 0xfa4f0bb5
    static let inputPhotoFileLocation: UInt32 = 0x40181ffe
    static let inputDocumentFileLocation: UInt32 = 0xbad07584
    static let inputMediaUploadedPhoto: UInt32 = 0x1e287d04
    static let inputMediaUploadedDocument: UInt32 = 0x037c9330
    static let documentAttributeFilename: UInt32 = 0x15590068
    static let documentAttributeVideo: UInt32 = 0x43c57c48
    static let documentAttributeAnimated: UInt32 = 0x11b58939
    static let documentAttributeAudio: UInt32 = 0x9852f9c6
    static let channelsGetParticipants: UInt32 = 0x77ced9d0
    static let channelsCreateChannel: UInt32 = 0x91006707
    static let channelsGetFullChannel: UInt32 = 0x08736a09
    static let channelsEditAdmin: UInt32 = 0xd33c8902
    static let channelsEditTitle: UInt32 = 0x566decd0
    static let channelsLeaveChannel: UInt32 = 0xf836aa95
    static let channelsInviteToChannel: UInt32 = 0xc9e33d54
    static let channelsExportMessageLink: UInt32 = 0xe63fadeb
    static let channelsEditBanned: UInt32 = 0x96e6cd81
    static let channelsDeleteParticipantHistory: UInt32 = 0x367544db
    static let channelsTogglePreHistoryHidden: UInt32 = 0xeabbb94c
    static let channelsToggleSlowMode: UInt32 = 0xedd49ef0
    static let channelsToggleJoinToSend: UInt32 = 0xe4cb9580
    static let channelsToggleJoinRequest: UInt32 = 0x4c2985b6
    static let channelsToggleParticipantsHidden: UInt32 = 0x6a6e7854
    static let channelsGetAdminLog: UInt32 = 0x33ddf480
    static let channelParticipantsRecent: UInt32 = 0xde3f3c79
    static let channelsChannelParticipants: UInt32 = 0x9ab0feaf
    static let channelsChannelParticipantsNotModified: UInt32 = 0xf0173fe9
    static let channelParticipant: UInt32 = 0xcb397619
    static let channelParticipantSelf: UInt32 = 0x4f607bef
    static let channelParticipantCreator: UInt32 = 0x2fe601d3
    static let channelParticipantAdmin: UInt32 = 0x34c3bb53
    static let channelParticipantBanned: UInt32 = 0x6df8014e
    static let channelParticipantLeft: UInt32 = 0x1b03f006
    static let exportedMessageLink: UInt32 = 0x5dab1af4
    static let chatInviteExported: UInt32 = 0xa22cbd96
    static let chatInvitePublicJoinRequests: UInt32 = 0xed107ab7
    static let channelsAdminLogResults: UInt32 = 0xed8af74d
    static let stickerSet: UInt32 = 0x2dd14edc
    static let stickerSetLegacy: UInt32 = 0xd7df217a
    static let stickerSetCovered: UInt32 = 0x6410a5d2
    static let stickerSetFullCovered: UInt32 = 0x40d13c0e
    static let stickerSetMultiCovered: UInt32 = 0x3407e51b
    static let stickerSetNoCovered: UInt32 = 0x77b15d1c
    static let messagesDialogs: UInt32 = 0x15ba6c40
    static let messagesPeerDialogs: UInt32 = 0x3371c354
    static let messagesDialogsSlice: UInt32 = 0x71e094f3
    static let messagesDialogsNotModified: UInt32 = 0xf0e3e596
    static let messagesMessages: UInt32 = 0x1d73e7ea
    static let messagesMessagesSlice: UInt32 = 0x5f206716
    static let messagesChannelMessages: UInt32 = 0xc776ba4e
    static let messagesMessagesNotModified: UInt32 = 0x74535f21
    static let messagesChatFull: UInt32 = 0xe5d7d19c
    static let chatFull: UInt32 = 0x2633421b
    static let channelFull: UInt32 = 0xe4e0b29d
    static let updatesState: UInt32 = 0xa56c2a3e
    static let updatesDifferenceEmpty: UInt32 = 0x5d75a138
    static let updatesDifference: UInt32 = 0x00f49ca0
    static let updatesDifferenceSlice: UInt32 = 0xa8fb1981
    static let updatesDifferenceTooLong: UInt32 = 0x4afe8f6d
    static let updateShortSentMessage: UInt32 = 0x9015e101
    static let updates: UInt32 = 0x74ae4240
    static let updatesCombined: UInt32 = 0x725b04c3
    static let updateShort: UInt32 = 0x78d4dec1
    static let updateShortMessage: UInt32 = 0x313bc7f8
    static let updateShortChatMessage: UInt32 = 0x4d6deea5
    static let updatesTooLong: UInt32 = 0xe317af7e
    static let updateNewMessage: UInt32 = 0x1f2b0afd
    static let updateMessageID: UInt32 = 0x4e90bfd6
    static let updateDeleteMessages: UInt32 = 0xa20db0e5
    static let updateUserTyping: UInt32 = 0x2a17bf5c
    static let updateChatUserTyping: UInt32 = 0x83487af0
    static let updateChatParticipants: UInt32 = 0x07761198
    static let updateUserStatus: UInt32 = 0xe5bdf8de
    static let updateUserName: UInt32 = 0xa7848924
    static let updateNewAuthorization: UInt32 = 0x8951abef
    static let updateChatParticipantAdd: UInt32 = 0x3dda5451
    static let updateChatParticipantDelete: UInt32 = 0xe32f3d77
    static let updateNotifySettings: UInt32 = 0xbec268ef
    static let updatePrivacy: UInt32 = 0xee3b272a
    static let updateUserPhone: UInt32 = 0x05492a13
    static let updateReadHistoryInbox: UInt32 = 0x9e84bc99
    static let updateReadHistoryInboxLegacy: UInt32 = 0x9c974fdf
    static let updateReadHistoryOutbox: UInt32 = 0x2f2f21bf
    static let updateWebPage: UInt32 = 0x7f891213
    static let updateReadMessagesContents: UInt32 = 0xf8227181
    static let updateChannelTooLong: UInt32 = 0x108d941f
    static let updateChannel: UInt32 = 0x635b4c09
    static let updateNewChannelMessage: UInt32 = 0x62ba04d9
    static let updateReadChannelInbox: UInt32 = 0x922e6e10
    static let updateDeleteChannelMessages: UInt32 = 0xc32d5b12
    static let updateChannelMessageViews: UInt32 = 0xf226ac08
    static let updateChatParticipantAdmin: UInt32 = 0xd7ca61a2
    static let updateEditMessage: UInt32 = 0xe40370a3
    static let updateEditChannelMessage: UInt32 = 0x1b3f4df7
    static let updateReadChannelOutbox: UInt32 = 0xb75f99a9
    static let updateReadFeaturedStickers: UInt32 = 0x571d2742
    static let updateRecentStickers: UInt32 = 0x9a422c20
    static let updateConfig: UInt32 = 0xa229dd06
    static let updatePtsChanged: UInt32 = 0x3354678f
    static let updateChannelWebPage: UInt32 = 0x2f2ba99f
    static let updateDialogPinned: UInt32 = 0x6e6fe51c
    static let updatePinnedDialogs: UInt32 = 0xfa0f3ca2
    static let updateChannelReadMessagesContents: UInt32 = 0x25f324f7
    static let updateChannelReadMessagesContentsLegacy: UInt32 = 0xea29055d
    static let updateChannelAvailableMessages: UInt32 = 0xb23fc698
    static let updateDialogUnreadMark: UInt32 = 0xb658f23e
    static let updateDialogUnreadMarkLegacy: UInt32 = 0xe16459c3
    static let updateContactsReset: UInt32 = 0x7084a7be
    static let updateChatDefaultBannedRights: UInt32 = 0x54c01850
    static let updateFolderPeers: UInt32 = 0x19360dc0
    static let updatePeerSettings: UInt32 = 0x6a7e7366
    static let updateGeoLiveViewed: UInt32 = 0x871fb939
    static let updateDialogFilter: UInt32 = 0x26ffde7d
    static let updateDialogFilterOrder: UInt32 = 0xa5d72105
    static let updateDialogFilters: UInt32 = 0x3504914f
    static let updateChannelMessageForwards: UInt32 = 0xd29a27f4
    static let updatePeerBlocked: UInt32 = 0xebe07752
    static let updateChannelUserTyping: UInt32 = 0x8c88c923
    static let updatePinnedMessages: UInt32 = 0xed85eab5
    static let updatePinnedChannelMessages: UInt32 = 0x5bb98608
    static let updateChat: UInt32 = 0xf89a6a4e
    static let updatePeerHistoryTTL: UInt32 = 0xbb9bb9a5
    static let updateChatParticipant: UInt32 = 0xd087663a
    static let updateChannelParticipant: UInt32 = 0x985d3abb
    static let updateBotCommands: UInt32 = 0x4d712f2e
    static let updatePendingJoinRequests: UInt32 = 0x7063c3db
    static let updateMessageReactions: UInt32 = 0x1e297bfa
    static let updateAttachMenuBots: UInt32 = 0x17b7a20b
    static let updateSavedRingtones: UInt32 = 0x74d8be99
    static let updateTranscribedAudio: UInt32 = 0x0084cd5a
    static let updateReadFeaturedEmojiStickers: UInt32 = 0xfb4c496c
    static let updateUserEmojiStatus: UInt32 = 0x28373599
    static let updateRecentEmojiStatuses: UInt32 = 0x30f443db
    static let updateRecentReactions: UInt32 = 0x6f7863f4
    static let updateMessageExtendedMedia: UInt32 = 0xd5a41724
    static let updateUser: UInt32 = 0x20529438
    static let updateAutoSaveSettings: UInt32 = 0xec05b097
    static let updatePeerWallpaper: UInt32 = 0xae3f101d
    static let updateBotMessageReaction: UInt32 = 0xac21d3ce
    static let updateBotMessageReactions: UInt32 = 0x09cb7759
    static let updateSavedDialogPinned: UInt32 = 0xaeaf9e74
    static let updatePinnedSavedDialogs: UInt32 = 0x686c85a6
    static let updateSavedReactionTags: UInt32 = 0x39c67432
    static let updateSavedGifs: UInt32 = 0x9375341e
    static let updateFavedStickers: UInt32 = 0xe511996d
    static let updateDraftMessage: UInt32 = 0xedfc111e
    static let updateDraftMessageLegacy: UInt32 = 0x1b49ec6d
    static let updateDraftMessageBare: UInt32 = 0xee2bb969
    static let dialog: UInt32 = 0xd58a08c6
    static let peerUser: UInt32 = 0x59511722
    static let peerChat: UInt32 = 0x36c6019a
    static let peerChannel: UInt32 = 0xa2a5371e
    static let messageEmpty: UInt32 = 0x90a6ca84
    static let message: UInt32 = 0x3ae56482
    static let messageService: UInt32 = 0x7a800e0a
    static let chatEmpty: UInt32 = 0x29562865
    static let chat: UInt32 = 0x41cbf256
    static let chatForbidden: UInt32 = 0x6592a1a7
    static let channel: UInt32 = 0x1c32b11c
    static let channelForbidden: UInt32 = 0x17d493d5
    static let privacyValueAllowAll: UInt32 = 0x65427b82
    static let privacyValueAllowContacts: UInt32 = 0xfffe1bac
    static let privacyValueDisallowAll: UInt32 = 0x8b73e763
    static let privacyValueAllowUsers: UInt32 = 0xb8905fb2
    static let privacyValueDisallowUsers: UInt32 = 0xe4621141
    static let privacyValueAllowChatParticipants: UInt32 = 0x6b134e8e
    static let privacyValueDisallowChatParticipants: UInt32 = 0x41c87565
    static let privacyValueAllowCloseFriends: UInt32 = 0xf7e8d89b
    static let privacyValueAllowPremium: UInt32 = 0xece9814b
    static let privacyValueAllowBots: UInt32 = 0x21461b5d
    static let privacyValueDisallowBots: UInt32 = 0xf6a5f82f
    static let privacyValueDisallowContacts: UInt32 = 0xf888fa1a
    static let chatParticipantsForbidden: UInt32 = 0x8763d3e1
    static let chatParticipants: UInt32 = 0x3cbc93f8
    static let chatParticipant: UInt32 = 0x38e79fde
    static let chatParticipantLegacy: UInt32 = 0xc02d4007
    static let chatParticipantCreator: UInt32 = 0xe1f867b8
    static let chatParticipantCreatorLegacy: UInt32 = 0xe46bcee4
    static let chatParticipantAdmin: UInt32 = 0x0360d5d2
    static let chatParticipantAdminLegacy: UInt32 = 0xa0933f5b
    static let chatPhotoEmpty: UInt32 = 0x37c1011c
    static let chatPhoto: UInt32 = 0x1c6e1c11
    static let inputChannelEmpty: UInt32 = 0xee8c1e86
    static let inputChannel: UInt32 = 0xf35aec28
    static let chatAdminRights: UInt32 = 0x5fb224d5
    static let chatBannedRights: UInt32 = 0x9f120418
    static let peerNotifySettings: UInt32 = 0x99622c0c
    static let draftMessageEmpty: UInt32 = 0x1b0c841a
    static let draftMessage: UInt32 = 0x96eaa5eb
    static let messageReplyHeader: UInt32 = 0x6917560b
    static let messageMediaEmpty: UInt32 = 0x3ded6320
    static let messageMediaPhoto: UInt32 = 0x695150d7
    static let messageMediaDocument: UInt32 = 0x52d8ccd9
    static let messageMediaContact: UInt32 = 0x70322949
    static let messageMediaUnsupported: UInt32 = 0x9f84f49e
    static let messageMediaGeo: UInt32 = 0x56e0d474
    static let messageMediaGeoLive: UInt32 = 0xb940c666
    static let messageMediaVenue: UInt32 = 0x2ec0533f
    static let messageMediaWebPage: UInt32 = 0xddf10c3b
    static let messageMediaDice: UInt32 = 0x8cbec07
    static let messageMediaStory: UInt32 = 0x68cb6283
    static let messageMediaPaidMedia: UInt32 = 0xa8852491
    static let messageFwdHeader: UInt32 = 0x4e4df4bb
    static let photoEmpty: UInt32 = 0x2331b22d
    static let photo: UInt32 = 0xfb197a65
    static let photoSizeEmpty: UInt32 = 0xe17e23c
    static let photoSize: UInt32 = 0x75c78e60
    static let photoSizeProgressive: UInt32 = 0xfa3efb95
    static let documentEmpty: UInt32 = 0x36f8c871
    static let document: UInt32 = 0x8fd4c4d8
    static let geoPointEmpty: UInt32 = 0x1117dd5f
    static let geoPoint: UInt32 = 0xb2a2f663
    static let webPageEmpty: UInt32 = 0x211a1788
    static let webPagePending: UInt32 = 0xb0d13e47
    static let webPage: UInt32 = 0xe89c45b2
    static let webPageNotModified: UInt32 = 0x7311ca11
    static let webPageAttributeTheme: UInt32 = 0x54b56617
    static let webPageAttributeStory: UInt32 = 0x2e94c3e7
    static let webPageAttributeStickerSet: UInt32 = 0x50cc03d3
    static let webPageAttributeUniqueStarGift: UInt32 = 0xcf6f6db8
    static let webPageAttributeStarGiftAuction: UInt32 = 0x01c641c2
    static let webPageAttributeStarGiftCollection: UInt32 = 0x31cad303
    static let user: UInt32 = 0x31774388
    static let userEmpty: UInt32 = 0xd3bc4b7a
    static let userProfilePhotoEmpty: UInt32 = 0x4f11bae1
    static let userProfilePhoto: UInt32 = 0x82d1f706
    static let userStatusEmpty: UInt32 = 0x09d05049
    static let userStatusOnline: UInt32 = 0xedb93949
    static let userStatusOffline: UInt32 = 0x8c703f
    static let userStatusRecently: UInt32 = 0x7b197dc8
    static let userStatusLastWeek: UInt32 = 0x541a1d1a
    static let userStatusLastMonth: UInt32 = 0x65899777
    static let restrictionReason: UInt32 = 0xd072acb4
    static let emojiStatusEmpty: UInt32 = 0x2de11aae
    static let emojiStatus: UInt32 = 0xe7ff068a
    static let emojiStatusCollectible: UInt32 = 0x7184603b
    static let username: UInt32 = 0xb4073647
    static let peerColor: UInt32 = 0xb54b5acf
}

struct HSNativeMTProtoProbe: Equatable {
    let nonce: Data
    let serverNonce: Data
    let pq: Data
    let publicKeyFingerprints: [Int64]
}

struct HSNativeServerDHMaterial: Equatable {
    let probe: HSNativeMTProtoProbe
    let newNonce: Data
    let p: Data
    let q: Data
    let g: Int32
    let dhPrime: Data
    let gA: Data
    let serverTime: Int32
}

struct HSNativeAuthKeyMaterial: Equatable {
    let serverDHMaterial: HSNativeServerDHMaterial
    let authKey: Data
    let authKeyID: Int64
    let serverSalt: Int64
    let timeDifference: Int32

    var credentials: HSNativeAuthKeyCredentials {
        HSNativeAuthKeyCredentials(
            authKey: authKey,
            authKeyID: authKeyID,
            serverSalt: serverSalt,
            timeDifference: timeDifference
        )
    }
}

struct HSNativeAuthKeyCredentials: Codable, Equatable {
    let authKey: Data
    let authKeyID: Int64
    let serverSalt: Int64
    let timeDifference: Int32
}

private struct HSNativeEncryptedMessage: Equatable {
    let salt: Int64
    let sessionID: Int64
    let messageID: Int64
    let seqNo: Int32
    let body: Data
}

private struct HSNativeSentCodeTypeInfo: Equatable {
    let emailPattern: String
    let codeLength: Int
}

struct HSNativePasswordChallenge: Equatable {
    let salt1: Data
    let salt2: Data
    let g: Int32
    let p: Data
    let srpB: Data
    let srpID: Int64
    let hint: String?
}

private struct HSNativeAccountPasswordInfo: Equatable {
    let settings: HSLoginPasswordSettings
    let currentChallenge: HSNativePasswordChallenge?
    let newAlgorithm: HSNativePasswordKDF.Algorithm?
}

struct HSNativePasswordKDFResult: Equatable {
    let id: Int64
    let a: Data
    let m1: Data
}

struct HSNativePasswordUpdateKDFResult: Equatable {
    let algorithm: HSNativePasswordKDF.Algorithm
    let passwordHash: Data
}

private enum HSNativePeer: Hashable {
    case user(Int64)
    case chat(Int64)
    case channel(Int64)

    var dialogID: Int64 {
        switch self {
        case .user(let id):
            return id
        case .chat(let id):
            return -id
        case .channel(let id):
            return HSNativePeer.channelDialogID(id)
        }
    }

    var isGroupLike: Bool {
        switch self {
        case .user:
            return false
        case .chat, .channel:
            return true
        }
    }

    static let channelDialogPrefix: Int64 = -1_000_000_000_000

    static func channelDialogID(_ channelID: Int64) -> Int64 {
        channelDialogPrefix - channelID
    }
}

private struct HSNativeCachedPeer: Equatable {
    let dialogID: Int64
    let inputPeerPayload: Data
    let inputChannelPayload: Data?
    let inputUserPayload: Data?
    let title: String
    let isGroupLike: Bool
}

private struct HSNativeParsedUser: Equatable {
    let id: Int64
    let accessHash: Int64?
    let title: String
    let username: String?
    let flags: UInt32

    var isBot: Bool {
        flags & (1 << 14) != 0
    }

    var isContact: Bool {
        flags & (1 << 11) != 0 || flags & (1 << 12) != 0
    }
}

private struct HSNativeParsedUserFull: Equatable {
    let id: Int64
    let about: String
}

private struct HSNativeParsedUserFullPayload: Equatable {
    let full: HSNativeParsedUserFull
    let users: [HSNativeParsedUser]
}

private struct HSNativeParsedChat: Equatable {
    let peer: HSNativePeer
    let accessHash: Int64?
    let title: String
    let isGroupLike: Bool
    let about: String
    let memberCount: Int
    let role: String
    let isMegagroup: Bool
    let isBroadcast: Bool
}

private struct HSNativeParsedDialog: Equatable {
    let peer: HSNativePeer
    let topMessageID: Int32
    let readInboxMaxID: Int32
    let readOutboxMaxID: Int32
    let unreadCount: Int32
    let isMarkedUnread: Bool
    let isPinned: Bool
    let folderID: Int?
    let isMuted: Bool
}

private struct HSNativeParsedMessage: Equatable {
    let id: Int32
    let peer: HSNativePeer?
    let fromPeer: HSNativePeer?
    let date: Int32?
    let text: String
    let kind: String?
    let media: HSMessageMedia?
    let isOutgoing: Bool
    let replyToMessageID: Int64?
    let reactions: [HSMessageReaction]
    let counters: HSMessageCounters
    let editDate: Int32?
    let authorSignature: String?
}

private struct HSNativeSyncDifferencePayload: Equatable {
    let state: HSSyncState
    let messages: [HSNativeParsedMessage]
    let affectedDialogIDs: [Int64]
    let readOutboxMaxIDsByDialogID: [Int64: Int64]
    let inputActivities: [HSInputActivity]
    let affectsAllDialogs: Bool
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
    let isTooLong: Bool
    let isSlice: Bool
}

private struct HSNativeParsedDifferenceUpdate: Equatable {
    let message: HSNativeParsedMessage?
    let affectedDialogIDs: [Int64]
    let readOutboxMaxIDsByDialogID: [Int64: Int64]
    let inputActivity: HSInputActivity?
    let affectsAllDialogs: Bool

    init(
        message: HSNativeParsedMessage?,
        affectedDialogIDs: [Int64],
        readOutboxMaxIDsByDialogID: [Int64: Int64] = [:],
        inputActivity: HSInputActivity? = nil,
        affectsAllDialogs: Bool
    ) {
        self.message = message
        self.affectedDialogIDs = affectedDialogIDs
        self.readOutboxMaxIDsByDialogID = readOutboxMaxIDsByDialogID
        self.inputActivity = inputActivity
        self.affectsAllDialogs = affectsAllDialogs
    }
}

private struct HSNativeParsedMediaSize: Equatable {
    let type: String?
    let width: Int?
    let height: Int?
    let bytes: Int64?
}

private struct HSNativeParsedDocumentAttributes: Equatable {
    var fileName: String?
    var width: Int?
    var height: Int?
    var duration: Double?
    var isVideo = false
    var isAnimated = false
    var isAudio = false
    var isVoice = false
    var waveform: Data?
    var isSticker = false
    var isCustomEmoji = false
}

private struct HSNativeDialogsPayload: Equatable {
    let dialogs: [HSNativeParsedDialog]
    let messages: [HSNativeParsedMessage]
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeMessagesPayload: Equatable {
    let messages: [HSNativeParsedMessage]
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeContactsPayload: Equatable {
    let contactUserIDs: Set<Int64>
    let users: [HSNativeParsedUser]
}

private struct HSNativeBlockedContactsPayload: Equatable {
    let blockedUserIDs: Set<Int64>
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeContactsFoundPayload: Equatable {
    let myResultUserIDs: Set<Int64>
    let resultUserIDs: Set<Int64>
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeResolvedPeerPayload: Equatable {
    let peer: HSNativePeer
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeChannelParticipantsPayload: Equatable {
    let members: [HSSupergroupMember]
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeAdminLogPayload: Equatable {
    let events: [HSSupergroupAdminLogEvent]
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeDraftsPayload: Equatable {
    let drafts: [HSDraft]
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private struct HSNativeAuthorizationsPayload: Equatable {
    let devices: [HSDeviceSession]
    let unconfirmedCount: Int
}

private struct HSNativeParsedChatFull: Equatable {
    let peer: HSNativePeer
    let about: String
    let memberCount: Int?
    let pendingRequests: Int?
    let isMegagroup: Bool
    let isBroadcast: Bool
}

private struct HSNativeChatFullPayload: Equatable {
    let full: HSNativeParsedChatFull
    let chats: [HSNativeParsedChat]
    let users: [HSNativeParsedUser]
}

private enum HSNativeNotifyScope {
    case privateChats
    case groups
    case channels

    var inputConstructor: UInt32 {
        switch self {
        case .privateChats:
            return HSNativeMTProtoSchema.inputNotifyUsers
        case .groups:
            return HSNativeMTProtoSchema.inputNotifyChats
        case .channels:
            return HSNativeMTProtoSchema.inputNotifyBroadcasts
        }
    }
}

private enum HSNativePrivacyRuleKind {
    case allowAll
    case allowContacts
    case disallowAll
    case allowUsers([Int64])
    case disallowUsers([Int64])
    case allowChats([Int64])
    case disallowChats([Int64])
    case custom
}

private struct HSNativePrivacySpec {
    let id: String
    let title: String
    let subtitle: String
    let key: UInt32
}

private struct HSNativePrivacyRulesSnapshot {
    let value: String
    let selection: HSPrivacyRuleValue
    let exceptions: HSPrivacyRuleExceptions
    let users: [HSNativeParsedUser]
    let chats: [HSNativeParsedChat]
}

private let hsNativePrivacySpecs: [HSNativePrivacySpec] = [
    HSNativePrivacySpec(id: "last_seen", title: "Last Seen & Online", subtitle: "Who can see your activity status", key: HSNativeMTProtoSchema.inputPrivacyKeyStatusTimestamp),
    HSNativePrivacySpec(id: "phone_number", title: "Phone Number", subtitle: "Who can discover or view your sign-in address", key: HSNativeMTProtoSchema.inputPrivacyKeyPhoneNumber),
    HSNativePrivacySpec(id: "profile_photo", title: "Profile Photo", subtitle: "Who can view your avatar", key: HSNativeMTProtoSchema.inputPrivacyKeyProfilePhoto),
    HSNativePrivacySpec(id: "about", title: "Bio", subtitle: "Who can view your profile bio", key: HSNativeMTProtoSchema.inputPrivacyKeyAbout),
    HSNativePrivacySpec(id: "calls", title: "Calls", subtitle: "Who can call you", key: HSNativeMTProtoSchema.inputPrivacyKeyPhoneCall),
    HSNativePrivacySpec(id: "groups", title: "Groups & Channels", subtitle: "Who can add you to groups and channels", key: HSNativeMTProtoSchema.inputPrivacyKeyChatInvite),
    HSNativePrivacySpec(id: "forwards", title: "Forwards", subtitle: "Who can link forwarded messages to your profile", key: HSNativeMTProtoSchema.inputPrivacyKeyForwards)
]

private struct HSNativeParsedChannelParticipant: Equatable {
    let userID: Int64
    let role: String
    let rank: String?
    let date: Int32?
}

private struct HSNativeStoredAuthKey: Codable {
    let token: String
    let userID: Int64
    let credentials: HSNativeAuthKeyCredentials
}

private struct HSNativeMTProtoAuthKeyStore {
    private let service = "cloud.hsgram.native.mtproto.authkey"

    func load(session: HSUserSession) -> HSNativeAuthKeyCredentials? {
        readValue(HSNativeStoredAuthKey.self, account: account(for: session))?.credentials
    }

    func save(_ credentials: HSNativeAuthKeyCredentials, session: HSUserSession) {
        let stored = HSNativeStoredAuthKey(token: session.token, userID: session.userID, credentials: credentials)
        writeValue(stored, account: account(for: session))
    }

    func delete(session: HSUserSession) {
        SecItemDelete(baseQuery(account: account(for: session)) as CFDictionary)
    }

    private func account(for session: HSUserSession) -> String {
        session.token.isEmpty ? "mtproto:\(session.userID)" : session.token
    }

    private func readValue<Value: Decodable>(_ type: Value.Type, account: String) -> Value? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func writeValue<Value: Encodable>(_ value: Value, account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        var item = baseQuery(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class HSNativeMTProtoClient {
    static let shared = HSNativeMTProtoClient()

    private let configuration: HSNativeMTProtoConfiguration
    private let transport: HSNativeMTProtoIntermediateTransport
    private let authKeyStore = HSNativeMTProtoAuthKeyStore()
    private let pendingAuthKeyQueue = DispatchQueue(label: "cloud.hsgram.native.mtproto.pending-auth-key")
    private let authorizedAuthKeyQueue = DispatchQueue(label: "cloud.hsgram.native.mtproto.authorized-auth-key")
    private let peerCacheQueue = DispatchQueue(label: "cloud.hsgram.native.mtproto.peer-cache")
    private var pendingAuthKeysByEmail: [String: HSNativeAuthKeyMaterial] = [:]
    private var pendingAuthKeysByTransaction: [String: HSNativeAuthKeyMaterial] = [:]
    private var authorizedAuthKeysByToken: [String: HSNativeAuthKeyCredentials] = [:]
    private var cachedPeersByDialogID: [Int64: HSNativeCachedPeer] = [:]
    private var cachedGroupsByDialogID: [Int64: HSSupergroup] = [:]

    init(configuration: HSNativeMTProtoConfiguration = .production) {
        self.configuration = configuration
        self.transport = HSNativeMTProtoIntermediateTransport(configuration: configuration)
    }

    func sendEmailCode(email: String) async throws -> HSEmailStartResponse {
        try await transport.withSession(timeout: 24) { session in
            let serverDHMaterial = try await self.requestServerDHParams(on: session)
            let authKey = try await self.completeAuthKeyHandshake(serverDHMaterial, on: session)
            let sessionID = try Self.randomInt64()
            do {
                let result = try await self.sendEncryptedRPC(
                    body: self.invokeWithLayerPayload(query: self.initConnectionPayload(query: self.authSendCodePayload(email: email))),
                    authKey: authKey,
                    sessionID: sessionID,
                    on: session
                )
                let response = try Self.parseAuthSentCodeResult(result, fallbackEmail: email)
                self.storePendingAuthKey(authKey, email: email, transactionID: response.transactionID)
                return response
            } catch let error as HSAPIError {
                if error.serverCode == "SESSION_PASSWORD_NEEDED" {
                    self.storePendingAuthKey(authKey, email: email, transactionID: nil)
                }
                throw error
            }
        }
    }

    func verifyEmailCode(email: String, code: String, transactionID: String, displayName: String) async throws -> HSUserSession {
        let authKey = try await pendingAuthKey(email: email, transactionID: transactionID)
        let result = try await sendEncryptedRPC(
            query: authSignInEmailPayload(email: email, phoneCodeHash: transactionID, code: code),
            authKey: authKey
        )
        let session = try Self.parseAuthorizationResult(result, email: email, fallbackName: displayName)
        storeAuthorizedAuthKey(authKey.credentials, session: session)
        clearPendingAuthKey(email: email, transactionID: transactionID)
        return session
    }

    func signUp(email: String, transactionID: String, displayName: String, inviteCode: String) async throws -> HSUserSession {
        let authKey = try await pendingAuthKey(email: email, transactionID: transactionID)
        let session = try await signUp(
            email: email,
            transactionID: transactionID,
            displayName: displayName,
            inviteCode: inviteCode,
            authKey: authKey
        )
        storeAuthorizedAuthKey(authKey.credentials, session: session)
        clearPendingAuthKey(email: email, transactionID: transactionID)
        return session
    }

    func uploadProfilePhoto(data: Data, session: HSUserSession) async throws {
        let credentials = try authorizedAuthKey(for: session)
        let inputFile = try await uploadMediaFile(
            data: data,
            fileName: "profile.jpg",
            credentials: credentials,
            progress: nil
        )
        let result = try await sendEncryptedRPC(
            query: photosUploadProfilePhotoPayload(file: inputFile),
            credentials: credentials
        )
        try Self.parsePhotosPhotoResult(result)
    }

    func removeProfilePhoto(session: HSUserSession) async throws {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: photosUpdateProfilePhotoPayload(id: inputPhotoEmptyPayload()),
            credentials: credentials
        )
        try Self.parsePhotosPhotoResult(result)
    }

    func verifyPassword(email: String, password: String) async throws -> HSUserSession {
        let authKey = try await pendingAuthKey(email: email, transactionID: "")
        let passwordData = try await sendEncryptedRPC(query: accountGetPasswordPayload(), authKey: authKey)
        let challenge = try Self.parseAccountPasswordResult(passwordData)
        let kdf = try HSNativePasswordKDF.result(password: password, challenge: challenge)
        let authorizationData = try await sendEncryptedRPC(query: authCheckPasswordPayload(kdf), authKey: authKey)
        let session = try Self.parseAuthorizationResult(authorizationData, email: email, fallbackName: email)
        storeAuthorizedAuthKey(authKey.credentials, session: session)
        clearPendingAuthKey(email: email, transactionID: "")
        return session
    }

    func requestPasswordRecovery(email: String) async throws -> HSPasswordRecoveryResponse {
        let authKey = try await pendingAuthKey(email: email, transactionID: "")
        let result = try await sendEncryptedRPC(
            query: authRequestPasswordRecoveryPayload(),
            authKey: authKey
        )
        return try Self.parsePasswordRecoveryResult(result)
    }

    func recoverPassword(email: String, code: String) async throws -> HSUserSession {
        let authKey = try await pendingAuthKey(email: email, transactionID: "")
        let result = try await sendEncryptedRPC(
            query: authRecoverPasswordPayload(code: code),
            authKey: authKey
        )
        let session = try Self.parseAuthorizationResult(result, email: email, fallbackName: email)
        storeAuthorizedAuthKey(authKey.credentials, session: session)
        clearPendingAuthKey(email: email, transactionID: "")
        return session
    }

    func loginPasswordSettings(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: accountGetPasswordPayload(),
            credentials: credentials
        )
        return try Self.parseAccountPasswordInfo(result).settings
    }

    func updateLoginPassword(
        currentPassword: String?,
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        session: HSUserSession
    ) async throws -> HSLoginPasswordSettings {
        let credentials = try authorizedAuthKey(for: session)
        let passwordInfo = try Self.parseAccountPasswordInfo(
            try await sendEncryptedRPC(query: accountGetPasswordPayload(), credentials: credentials)
        )
        let currentCheck: Data
        if let challenge = passwordInfo.currentChallenge {
            let trimmedCurrent = currentPassword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedCurrent.isEmpty else {
                throw HSAPIError.server(code: "PASSWORD_REQUIRED", message: "请输入当前登录密码。")
            }
            currentCheck = inputCheckPasswordSRPPayload(try HSNativePasswordKDF.result(password: trimmedCurrent, challenge: challenge))
        } else {
            currentCheck = inputCheckPasswordEmptyPayload()
        }

        let trimmedNewPassword = newPassword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newSettings = try accountPasswordInputSettingsPayload(
            newPassword: trimmedNewPassword.isEmpty ? nil : trimmedNewPassword,
            hint: hint,
            recoveryEmail: recoveryEmail,
            newAlgorithm: passwordInfo.newAlgorithm
        )
        let ok = try Self.parseBoolResult(
            try await sendEncryptedRPC(
                query: accountUpdatePasswordSettingsPayload(password: currentCheck, newSettings: newSettings),
                credentials: credentials
            )
        )
        guard ok else {
            throw HSAPIError.server(code: "PASSWORD_SETTINGS_FAILED", message: "登录密码设置没有被服务端接受。")
        }
        return try await loginPasswordSettings(session: session)
    }

    func confirmLoginPasswordEmail(code: String, session: HSUserSession) async throws -> HSLoginPasswordSettings {
        let credentials = try authorizedAuthKey(for: session)
        let ok = try Self.parseBoolResult(
            try await sendEncryptedRPC(
                query: accountConfirmPasswordEmailPayload(code: code),
                credentials: credentials
            )
        )
        guard ok else {
            throw HSAPIError.server(code: "PASSWORD_EMAIL_CONFIRM_FAILED", message: "恢复邮箱验证码没有被服务端接受。")
        }
        return try await loginPasswordSettings(session: session)
    }

    func resendLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        let credentials = try authorizedAuthKey(for: session)
        let ok = try Self.parseBoolResult(
            try await sendEncryptedRPC(
                query: accountResendPasswordEmailPayload(),
                credentials: credentials
            )
        )
        guard ok else {
            throw HSAPIError.server(code: "PASSWORD_EMAIL_RESEND_FAILED", message: "恢复邮箱验证码重新发送失败。")
        }
        return try await loginPasswordSettings(session: session)
    }

    func cancelLoginPasswordEmail(session: HSUserSession) async throws -> HSLoginPasswordSettings {
        let credentials = try authorizedAuthKey(for: session)
        let ok = try Self.parseBoolResult(
            try await sendEncryptedRPC(
                query: accountCancelPasswordEmailPayload(),
                credentials: credentials
            )
        )
        guard ok else {
            throw HSAPIError.server(code: "PASSWORD_EMAIL_CANCEL_FAILED", message: "恢复邮箱确认取消失败。")
        }
        return try await loginPasswordSettings(session: session)
    }

    func syncState(session: HSUserSession) async throws -> HSSyncState {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: updatesGetStatePayload(),
            credentials: credentials
        )
        return try Self.parseSyncStateResult(result)
    }

    func syncDifference(since state: HSSyncState, session: HSUserSession) async throws -> HSSyncDifference {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: updatesGetDifferencePayload(state: state, ptsTotalLimit: 100),
            credentials: credentials
        )
        let payload: HSNativeSyncDifferencePayload
        do {
            payload = try Self.parseSyncDifferenceResult(result, previousState: state)
        } catch {
            let resetState = try await syncState(session: session)
            return HSSyncDifference(
                state: resetState,
                messages: [],
                changedDialogIDs: [],
                readOutboxMaxIDsByDialogID: [:],
                inputActivities: [],
                affectsAllDialogs: true,
                isTooLong: true,
                isSlice: false
            )
        }

        cache(users: payload.users, chats: payload.chats)
        let messages = payload.messages.compactMap {
            Self.hsMessage(
                from: $0,
                fallbackDialogID: $0.peer?.dialogID ?? 0,
                users: payload.users,
                chats: payload.chats,
                sessionUserID: session.userID
            )
        }
        let changedDialogIDs = Array(Set(messages.map(\.dialogID) + payload.affectedDialogIDs)).sorted()
        var difference = HSSyncDifference(
            state: payload.state,
            messages: messages,
            changedDialogIDs: changedDialogIDs,
            readOutboxMaxIDsByDialogID: payload.readOutboxMaxIDsByDialogID,
            inputActivities: payload.inputActivities,
            affectsAllDialogs: payload.affectsAllDialogs,
            isTooLong: payload.isTooLong,
            isSlice: payload.isSlice
        )
        if payload.isTooLong {
            difference = difference.withState(try await syncState(session: session))
        }
        return difference
    }

    func dialogs(limit: Int = 80, folderID: Int? = nil, session: HSUserSession) async throws -> [HSChat] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesGetDialogsPayload(limit: limit, folderID: folderID),
            credentials: credentials
        )
        let payload = try Self.parseDialogsResult(result)
        cache(users: payload.users, chats: payload.chats)

        let messagesByID = payload.messages.reduce(into: [Int32: HSNativeParsedMessage]()) { result, message in
            result[message.id] = message
        }
        return payload.dialogs.map { dialog in
            let topMessage = messagesByID[dialog.topMessageID]
            let user = Self.parsedUser(for: dialog.peer, users: payload.users)
            let chat = Self.parsedChat(for: dialog.peer, chats: payload.chats)
            return HSChat(
                id: dialog.peer.dialogID,
                title: peerTitle(dialog.peer, users: payload.users, chats: payload.chats),
                subtitle: topMessage.map(Self.messageListText) ?? "No messages yet.",
                unreadCount: Int(dialog.unreadCount),
                readInboxMaxID: Int64(dialog.readInboxMaxID),
                readOutboxMaxID: Int64(dialog.readOutboxMaxID),
                topMessageID: topMessage.map { Int64($0.id) },
                topMessageIsOutgoing: topMessage?.isOutgoing ?? false,
                isMarkedUnread: dialog.isMarkedUnread,
                isPinned: dialog.isPinned,
                folderID: dialog.folderID,
                isCircle: dialog.peer.isGroupLike,
                peerKind: Self.peerKind(from: dialog.peer),
                isBot: user?.isBot ?? false,
                isContact: user?.isContact ?? false,
                isBroadcast: chat?.isBroadcast ?? false,
                isMuted: dialog.isMuted,
                updatedAt: topMessage?.date.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            )
        }
    }

    func dialogFilters(session: HSUserSession) async throws -> HSChatListFiltersState {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesGetDialogFiltersPayload(),
            credentials: credentials
        )
        return try Self.parseDialogFiltersResult(result, sessionUserID: session.userID)
    }

    func updateDialogFilter(_ filter: HSChatListFilter, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let payload = try dialogFilterPayload(filter, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesUpdateDialogFilterPayload(id: filter.id, filterPayload: payload),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func deleteDialogFilter(id: Int, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesUpdateDialogFilterPayload(id: id, filterPayload: nil),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func reorderDialogFilters(ids: [Int], session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesUpdateDialogFiltersOrderPayload(ids: ids),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func toggleDialogFilterTags(enabled: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesToggleDialogFilterTagsPayload(enabled: enabled),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func groups(limit: Int = 80, broadcastOnly: Bool?, session: HSUserSession) async throws -> [HSSupergroup] {
        _ = try await dialogs(limit: limit, session: session)
        let groups = peerCacheQueue.sync {
            Array(cachedGroupsByDialogID.values)
        }
        let filtered: [HSSupergroup]
        if let broadcastOnly {
            filtered = groups.filter { $0.isBroadcast == broadcastOnly }
        } else {
            filtered = groups
        }
        return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func group(dialogID: Int64, session: HSUserSession) async throws -> HSSupergroup {
        let credentials = try authorizedAuthKey(for: session)
        if dialogID < 0, dialogID > HSNativePeer.channelDialogPrefix {
            let result = try await sendEncryptedRPC(
                query: messagesGetFullChatPayload(chatID: -dialogID),
                credentials: credentials
            )
            let payload = try Self.parseChatFullResult(result)
            cache(users: payload.users, chats: payload.chats)
            return try cacheAndBuildGroup(dialogID: dialogID, full: payload.full, chats: payload.chats)
        }

        let channel: Data
        do {
            channel = try inputChannelPayload(dialogID: dialogID)
        } catch {
            _ = try await dialogs(limit: 80, session: session)
            channel = try inputChannelPayload(dialogID: dialogID)
        }
        let result = try await sendEncryptedRPC(
            query: channelsGetFullChannelPayload(channel: channel),
            credentials: credentials
        )
        let payload = try Self.parseChatFullResult(result)
        cache(users: payload.users, chats: payload.chats)
        return try cacheAndBuildGroup(dialogID: dialogID, full: payload.full, chats: payload.chats)
    }

    private func cacheAndBuildGroup(dialogID: Int64, full: HSNativeParsedChatFull, chats: [HSNativeParsedChat]) throws -> HSSupergroup {
        guard full.peer.dialogID == dialogID else {
            throw HSAPIError.server(code: "GROUP_DETAIL_MISMATCH", message: "服务端返回的群详情和当前会话不一致。")
        }
        let parsed = chats.first { $0.peer == full.peer }.flatMap(Self.supergroup(from:))
        let cached = peerCacheQueue.sync(execute: { cachedGroupsByDialogID[dialogID] })
        guard let base = parsed ?? cached else {
            throw HSAPIError.server(code: "GROUP_NOT_FOUND", message: "服务端返回了详情，但没有带回可解析的群资料。")
        }
        let group = HSSupergroup(
            id: dialogID,
            channelID: base.channelID,
            title: base.title,
            about: full.about,
            memberCount: full.memberCount ?? base.memberCount,
            pendingRequests: full.pendingRequests ?? base.pendingRequests,
            role: base.role,
            isMegagroup: parsed?.isMegagroup ?? (base.isMegagroup || full.isMegagroup),
            isBroadcast: parsed?.isBroadcast ?? (full.isBroadcast || base.isBroadcast)
        )
        peerCacheQueue.sync {
            cachedGroupsByDialogID[dialogID] = group
        }
        return group
    }

    func createGroup(title: String, about: String, memberIDs: [Int64], isBroadcast: Bool, session: HSUserSession) async throws -> HSSupergroup {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_GROUP_TITLE", message: "群或频道名称不能为空。")
        }
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsCreateChannelPayload(title: cleanTitle, about: about, isBroadcast: isBroadcast),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        let refreshed = try await groups(limit: 100, broadcastOnly: isBroadcast, session: session)
        guard let created = refreshed.first(where: { $0.title == cleanTitle }) ?? refreshed.first else {
            throw HSAPIError.server(code: "GROUP_CREATE_UNVERIFIED", message: "服务端已返回创建结果，但没有带回可解析的群资料。")
        }
        if !memberIDs.isEmpty {
            _ = try? await inviteGroupMembers(dialogID: created.id, userIDs: memberIDs, session: session)
        }
        return created
    }

    func updateGroup(dialogID: Int64, title: String?, about: String?, session: HSUserSession) async throws -> HSSupergroup {
        let credentials = try authorizedAuthKey(for: session)
        if let title {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty {
                let result = try await sendEncryptedRPC(
                    query: channelsEditTitlePayload(channel: try inputChannelPayload(dialogID: dialogID), title: cleanTitle),
                    credentials: credentials
                )
                try Self.parseUpdatesSuccess(result)
            }
        }
        var current = try await group(dialogID: dialogID, session: session)
        if let about {
            let result = try await sendEncryptedRPC(
                query: messagesEditChatAboutPayload(
                    peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                    about: about
                ),
                credentials: credentials
            )
            _ = try Self.parseBoolResult(result)
            current = HSSupergroup(
                id: current.id,
                channelID: current.channelID,
                title: title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title!.trimmingCharacters(in: .whitespacesAndNewlines) : current.title,
                about: about,
                memberCount: current.memberCount,
                pendingRequests: current.pendingRequests,
                role: current.role,
                isMegagroup: current.isMegagroup,
                isBroadcast: current.isBroadcast
            )
            peerCacheQueue.sync {
                cachedGroupsByDialogID[dialogID] = current
            }
        } else if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            current = try await group(dialogID: dialogID, session: session)
        }
        return current
    }

    func leaveGroup(dialogID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsLeaveChannelPayload(channel: try inputChannelPayload(dialogID: dialogID)),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func groupMembers(dialogID: Int64, limit: Int, offset: Int, session: HSUserSession) async throws -> [HSSupergroupMember] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsGetParticipantsPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                offset: offset,
                limit: limit
            ),
            credentials: credentials
        )
        let payload = try Self.parseChannelParticipantsResult(result, sessionUserID: session.userID)
        cache(users: payload.users, chats: payload.chats)
        return payload.members
    }

    func inviteGroupMembers(dialogID: Int64, userIDs: [Int64], session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let users = try userIDs.map(inputUserPayload(userID:))
        let result = try await sendEncryptedRPC(
            query: channelsInviteToChannelPayload(channel: try inputChannelPayload(dialogID: dialogID), users: users),
            credentials: credentials
        )
        try Self.parseInvitedUsersOrUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func editGroupAdmin(dialogID: Int64, userID: Int64, rights: HSSupergroupAdminRights, rank: String?, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsEditAdminPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                user: try inputUserPayload(userID: userID),
                rights: rights,
                rank: rank
            ),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func removeGroupMember(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsEditBannedPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                participant: try inputPeerPayload(dialogID: userID, sessionUserID: session.userID),
                rights: HSSupergroupBannedRights(viewMessages: true)
            ),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func editGroupRestrictions(dialogID: Int64, userID: Int64, rights: HSSupergroupBannedRights, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsEditBannedPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                participant: try inputPeerPayload(dialogID: userID, sessionUserID: session.userID),
                rights: rights
            ),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func deleteGroupMemberHistory(dialogID: Int64, userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsDeleteParticipantHistoryPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                participant: try inputPeerPayload(dialogID: userID, sessionUserID: session.userID)
            ),
            credentials: credentials
        )
        return try Self.parseAffectedHistoryResult(result, dialogID: dialogID)
    }

    func updateGroupSettings(dialogID: Int64, settings: HSSupergroupSettings, session: HSUserSession) async throws -> HSSupergroup {
        let credentials = try authorizedAuthKey(for: session)
        let channel = try inputChannelPayload(dialogID: dialogID)
        if let slowModeSeconds = settings.slowModeSeconds {
            try Self.parseUpdatesSuccess(try await sendEncryptedRPC(
                query: channelsToggleSlowModePayload(channel: channel, seconds: slowModeSeconds),
                credentials: credentials
            ))
        }
        if let participantsHidden = settings.participantsHidden {
            try Self.parseUpdatesSuccess(try await sendEncryptedRPC(
                query: channelsToggleParticipantsHiddenPayload(channel: channel, enabled: participantsHidden),
                credentials: credentials
            ))
        }
        if let preHistoryHidden = settings.preHistoryHidden {
            try Self.parseUpdatesSuccess(try await sendEncryptedRPC(
                query: channelsTogglePreHistoryHiddenPayload(channel: channel, enabled: preHistoryHidden),
                credentials: credentials
            ))
        }
        if let joinToSend = settings.joinToSend {
            try Self.parseUpdatesSuccess(try await sendEncryptedRPC(
                query: channelsToggleJoinToSendPayload(channel: channel, enabled: joinToSend),
                credentials: credentials
            ))
        }
        if let joinRequest = settings.joinRequest {
            try Self.parseUpdatesSuccess(try await sendEncryptedRPC(
                query: channelsToggleJoinRequestPayload(channel: channel, enabled: joinRequest),
                credentials: credentials
            ))
        }
        return try await group(dialogID: dialogID, session: session)
    }

    func pinGroupMessage(dialogID: Int64, messageID: Int64, silent: Bool, unpin: Bool, session: HSUserSession) async throws -> HSMessage {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesUpdatePinnedMessagePayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                messageID: messageID,
                silent: silent,
                unpin: unpin
            ),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessage(
            id: Int64(Date().timeIntervalSince1970 * 1000),
            dialogID: dialogID,
            authorID: session.userID,
            authorName: "You",
            text: unpin ? "Message unpinned" : "Message pinned",
            kind: "service",
            sentAt: Date(),
            isOutgoing: true,
            replyToMessageID: messageID
        )
    }

    func groupMessageLink(dialogID: Int64, messageID: Int64, session: HSUserSession) async throws -> HSExportedMessageLink {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: channelsExportMessageLinkPayload(channel: try inputChannelPayload(dialogID: dialogID), messageID: messageID),
            credentials: credentials
        )
        return try Self.parseExportedMessageLinkResult(result)
    }

    func exportInvite(dialogID: Int64, title: String?, expireDate: Int?, usageLimit: Int?, requestNeeded: Bool, session: HSUserSession) async throws -> HSExportedInvite {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesExportChatInvitePayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                title: title,
                expireDate: expireDate,
                usageLimit: usageLimit,
                requestNeeded: requestNeeded
            ),
            credentials: credentials
        )
        return try Self.parseExportedInviteResult(result, requestNeeded: requestNeeded, fallbackTitle: title)
    }

    func groupAdminLog(dialogID: Int64, query: String?, adminIDs: [Int64], limit: Int, session: HSUserSession) async throws -> [HSSupergroupAdminLogEvent] {
        let credentials = try authorizedAuthKey(for: session)
        let admins = try adminIDs.map(inputUserPayload(userID:))
        let result = try await sendEncryptedRPC(
            query: channelsGetAdminLogPayload(
                channel: try inputChannelPayload(dialogID: dialogID),
                query: query,
                admins: admins,
                limit: limit
            ),
            credentials: credentials
        )
        let payload = try Self.parseAdminLogResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.events
    }

    func messages(dialogID: Int64, beforeID: Int64?, limit: Int, session: HSUserSession) async throws -> [HSMessage] {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesGetHistoryPayload(peer: inputPeer, beforeID: beforeID, limit: limit),
            credentials: credentials
        )
        let payload = try Self.parseMessagesResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.messages.compactMap { message in
            Self.hsMessage(
                from: message,
                fallbackDialogID: dialogID,
                users: payload.users,
                chats: payload.chats,
                sessionUserID: session.userID
            )
        }
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.id < rhs.id
            }
            return lhs.sentAt < rhs.sentAt
        }
    }

    func sharedMedia(
        dialogID: Int64,
        filter: HSSharedMediaFilter,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> [HSMessage] {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesSearchPayload(
                peer: inputPeer,
                query: "",
                filter: filter,
                offsetID: offsetID,
                limit: limit
            ),
            credentials: credentials
        )
        let payload = try Self.parseMessagesResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.messages.compactMap { message in
            Self.hsMessage(
                from: message,
                fallbackDialogID: dialogID,
                users: payload.users,
                chats: payload.chats,
                sessionUserID: session.userID
            )
        }
        .sorted { lhs, rhs in
            if lhs.sentAt == rhs.sentAt {
                return lhs.id > rhs.id
            }
            return lhs.sentAt > rhs.sentAt
        }
    }

    func searchMessages(
        dialogID: Int64,
        query: String,
        offsetID: Int64?,
        limit: Int,
        session: HSUserSession
    ) async throws -> [HSSearchMessage] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return []
        }
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesSearchPayload(
                peer: inputPeer,
                query: cleanQuery,
                filter: nil,
                offsetID: offsetID,
                limit: limit
            ),
            credentials: credentials
        )
        let payload = try Self.parseMessagesResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.messages.compactMap { message -> HSSearchMessage? in
            guard let mapped = Self.hsMessage(
                from: message,
                fallbackDialogID: dialogID,
                users: payload.users,
                chats: payload.chats,
                sessionUserID: session.userID
            ) else {
                return nil
            }
            let peer = message.peer
            return HSSearchMessage(
                id: mapped.id,
                dialogID: mapped.dialogID,
                dialogTitle: peer.map { peerTitle($0, users: payload.users, chats: payload.chats) } ?? "Chat",
                authorID: mapped.authorID,
                authorName: mapped.authorName,
                text: mapped.text,
                kind: mapped.kind,
                sentAt: mapped.sentAt,
                isOutgoing: mapped.isOutgoing,
                isGroup: peer?.isGroupLike ?? false,
                isChannel: {
                    if case .channel = peer {
                        return true
                    }
                    return false
                }()
            )
        }
    }

    func sharedMediaCounters(
        dialogID: Int64,
        filters: [HSSharedMediaFilter],
        session: HSUserSession
    ) async throws -> [HSSharedMediaCounter] {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let requestedFilters = filters.isEmpty ? HSSharedMediaFilter.allCases : filters
        let result = try await sendEncryptedRPC(
            query: messagesGetSearchCountersPayload(
                peer: inputPeer,
                filters: requestedFilters
            ),
            credentials: credentials
        )
        return try Self.parseSearchCountersResult(result)
    }

    func webPagePreview(text: String, session: HSUserSession) async throws -> HSWebPagePreview? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return nil
        }
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesGetWebPagePreviewPayload(message: cleanText),
            credentials: credentials
        )
        return try Self.parseWebPagePreviewResult(result)?.webPage
    }

    func sendTextMessage(
        dialogID: Int64,
        text: String,
        replyToMessageID: Int64?,
        noWebpage: Bool = false,
        session: HSUserSession
    ) async throws -> HSMessage {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_MESSAGE", message: "不能发送空消息。")
        }
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesSendMessagePayload(peer: inputPeer, text: cleanText, replyToMessageID: replyToMessageID, noWebpage: noWebpage),
            credentials: credentials
        )
        return try Self.parseSendMessageResult(
            result,
            dialogID: dialogID,
            text: cleanText,
            replyToMessageID: replyToMessageID,
            sessionUserID: session.userID
        )
    }

    func sendMediaMessage(
        dialogID: Int64,
        fileName: String,
        mimeType: String,
        data: Data,
        mediaKind: String,
        caption: String,
        replyToMessageID: Int64?,
        duration: Double? = nil,
        waveform: Data? = nil,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)? = nil
    ) async throws -> HSMessage {
        guard !data.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_MEDIA", message: "不能发送空文件。")
        }
        let credentials = try authorizedAuthKey(for: session)
        let uploadedFile = try await uploadMediaFile(
            data: data,
            fileName: fileName,
            credentials: credentials,
            progress: progress
        )
        let media = inputMediaPayload(
            file: uploadedFile,
            fileName: fileName,
            mimeType: mimeType,
            mediaKind: mediaKind,
            duration: duration,
            waveform: waveform
        )
        let result = try await sendEncryptedRPC(
            query: messagesSendMediaPayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                media: media,
                caption: caption,
                replyToMessageID: replyToMessageID
            ),
            credentials: credentials
        )
        progress?(HSMediaTransferProgress(completedBytes: Int64(data.count), totalBytes: Int64(data.count)))
        return try Self.parseSendMessageResult(
            result,
            dialogID: dialogID,
            text: caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fileName : caption,
            replyToMessageID: replyToMessageID,
            sessionUserID: session.userID
        )
    }

    func setTyping(
        dialogID: Int64,
        activity: HSInputActivityKind,
        progress: Int?,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesSetTypingPayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                activity: activity,
                progress: progress
            ),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func downloadMedia(
        _ media: HSMessageMedia,
        session: HSUserSession,
        progress: ((HSMediaTransferProgress) -> Void)? = nil
    ) async throws -> Data {
        guard let location = media.location else {
            throw HSNativeMTProtoError.malformedPacket("message media does not include a downloadable MTProto file location")
        }
        let credentials = try authorizedAuthKey(for: session)
        let chunkSize = 512 * 1024
        let expectedSize = media.size.flatMap { $0 > 0 ? Int(clamping: $0) : nil }
        let expectedBytes = expectedSize.map(Int64.init)
        var offset = 0
        var data = Data()
        progress?(HSMediaTransferProgress(completedBytes: 0, totalBytes: expectedBytes))
        while true {
            try Task.checkCancellation()
            let requested = expectedSize.map { min(chunkSize, max(0, $0 - offset)) } ?? chunkSize
            guard requested > 0 else {
                break
            }
            let result = try await sendEncryptedRPC(
                query: uploadGetFilePayload(location: location, offset: Int64(offset), limit: requested),
                credentials: credentials
            )
            let chunk = try Self.parseUploadFileResult(result)
            guard !chunk.isEmpty else {
                break
            }
            data.append(chunk)
            offset += chunk.count
            progress?(HSMediaTransferProgress(completedBytes: Int64(offset), totalBytes: expectedBytes))
            if let expectedSize, offset >= expectedSize {
                break
            }
            if chunk.count < requested {
                break
            }
        }
        guard !data.isEmpty else {
            throw HSNativeMTProtoError.malformedPacket("media download returned no bytes")
        }
        return data
    }

    func saveDraft(
        dialogID: Int64,
        text: String,
        replyToMessageID: Int64?,
        noWebpage: Bool = false,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesSaveDraftPayload(peer: inputPeer, text: text, replyToMessageID: replyToMessageID, noWebpage: noWebpage),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func drafts(session: HSUserSession) async throws -> [HSDraft] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesGetAllDraftsPayload(),
            credentials: credentials
        )
        let payload = try Self.parseDraftsResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.drafts.sorted {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }
    }

    func markRead(dialogID: Int64, maxMessageID: Int64?, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesReadHistoryPayload(peer: inputPeer, maxMessageID: maxMessageID),
            credentials: credentials
        )
        return try Self.parseAffectedMessagesResult(result, dialogID: dialogID, messageID: maxMessageID)
    }

    func dialogReadState(dialogID: Int64, session: HSUserSession) async throws -> HSDialogReadState {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesGetPeerDialogsPayload(peer: inputPeer),
            credentials: credentials
        )
        let payload = try Self.parsePeerDialogsResult(result)
        cache(users: payload.users, chats: payload.chats)
        guard let dialog = payload.dialogs.first(where: { $0.peer.dialogID == dialogID }) ?? payload.dialogs.first else {
            throw HSAPIError.server(code: "DIALOG_READ_STATE_NOT_FOUND", message: "Server did not return read state for this dialog.")
        }
        return HSDialogReadState(
            dialogID: dialog.peer.dialogID,
            readInboxMaxID: Int64(dialog.readInboxMaxID),
            readOutboxMaxID: Int64(dialog.readOutboxMaxID),
            unreadCount: Int(dialog.unreadCount),
            isMarkedUnread: dialog.isMarkedUnread
        )
    }

    func markUnread(dialogID: Int64, unread: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesMarkDialogUnreadPayload(peer: inputPeer, unread: unread),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func toggleDialogPin(dialogID: Int64, pinned: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesToggleDialogPinPayload(peer: inputPeer, pinned: pinned),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func reorderPinnedDialogs(dialogIDs: [Int64], folderID: Int, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let peers = try dialogIDs.map { dialogID in
            try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        }
        let result = try await sendEncryptedRPC(
            query: messagesReorderPinnedDialogsPayload(peers: peers, folderID: folderID),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func editPeerFolder(dialogID: Int64, folderID: Int, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: foldersEditPeerFoldersPayload(peer: inputPeer, folderID: folderID),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func editMessage(dialogID: Int64, messageID: Int64, text: String, session: HSUserSession) async throws -> HSMessage {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_MESSAGE", message: "不能编辑为空消息。")
        }
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: messagesEditMessagePayload(peer: inputPeer, messageID: messageID, text: cleanText),
            credentials: credentials
        )
        return try Self.parseSendMessageResult(
            result,
            dialogID: dialogID,
            text: cleanText,
            replyToMessageID: nil,
            sessionUserID: session.userID
        )
    }

    func deleteMessage(dialogID: Int64, messageID: Int64, revoke: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesDeleteMessagesPayload(messageID: messageID, revoke: revoke),
            credentials: credentials
        )
        return try Self.parseAffectedMessagesResult(result, dialogID: dialogID, messageID: messageID)
    }

    func deleteDialogHistory(
        dialogID: Int64,
        justClear: Bool,
        revoke: Bool,
        maxMessageID: Int64?,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesDeleteHistoryPayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                justClear: justClear,
                revoke: revoke,
                maxMessageID: maxMessageID
            ),
            credentials: credentials
        )
        return try Self.parseAffectedHistoryResult(result, dialogID: dialogID)
    }

    func forwardMessage(dialogID: Int64, messageID: Int64, toDialogID: Int64, session: HSUserSession) async throws -> HSMessage {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesForwardMessagesPayload(
                fromPeer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                messageID: messageID,
                toPeer: try inputPeerPayload(dialogID: toDialogID, sessionUserID: session.userID)
            ),
            credentials: credentials
        )
        return try Self.parseForwardMessageResult(result, toDialogID: toDialogID, sessionUserID: session.userID)
    }

    func sendReaction(dialogID: Int64, messageID: Int64, reaction: String, big: Bool, session: HSUserSession) async throws -> HSMessageAction {
        let cleanReaction = reaction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanReaction.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_REACTION", message: "回应不能为空。")
        }
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: messagesSendReactionPayload(
                peer: try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID),
                messageID: messageID,
                reaction: cleanReaction,
                big: big
            ),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: messageID, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func search(query: String, limit: Int, session: HSUserSession) async throws -> HSSearchResults {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return HSSearchResults(query: "", dialogs: [], contacts: [], messages: [])
        }
        let credentials = try authorizedAuthKey(for: session)
        async let contactMatches = searchContacts(query: cleanQuery, limit: limit, session: session)
        let result = try await sendEncryptedRPC(
            query: messagesSearchGlobalPayload(query: cleanQuery, limit: limit),
            credentials: credentials
        )
        let payload = try Self.parseMessagesResult(result)
        cache(users: payload.users, chats: payload.chats)
        let messages = payload.messages.compactMap { message -> HSSearchMessage? in
            guard let mapped = Self.hsMessage(
                from: message,
                fallbackDialogID: 0,
                users: payload.users,
                chats: payload.chats,
                sessionUserID: session.userID
            ) else {
                return nil
            }
            let peer = message.peer
            return HSSearchMessage(
                id: mapped.id,
                dialogID: mapped.dialogID,
                dialogTitle: peer.map { peerTitle($0, users: payload.users, chats: payload.chats) } ?? "Chat",
                authorID: mapped.authorID,
                authorName: mapped.authorName,
                text: mapped.text,
                kind: mapped.kind,
                sentAt: mapped.sentAt,
                isOutgoing: mapped.isOutgoing,
                isGroup: peer?.isGroupLike ?? false,
                isChannel: {
                    if case .channel = peer {
                        return true
                    }
                    return false
                }()
            )
        }
        let contacts = (try? await contactMatches) ?? []
        return HSSearchResults(query: cleanQuery, dialogs: [], contacts: contacts, messages: messages)
    }

    func contacts(session: HSUserSession) async throws -> [HSContact] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(query: contactsGetContactsPayload(), credentials: credentials)
        let payload = try Self.parseContactsResult(result)
        cache(users: payload.users, chats: [])
        return payload.users.compactMap { user in
            guard payload.contactUserIDs.contains(user.id) else {
                return nil
            }
            return Self.hsContact(from: user, forcedStatus: nil)
        }
    }

    func blockedContacts(offset: Int = 0, limit: Int = 100, session: HSUserSession) async throws -> [HSContact] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: contactsGetBlockedPayload(offset: offset, limit: limit),
            credentials: credentials
        )
        let payload = try Self.parseBlockedContactsResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.users.compactMap { user in
            guard payload.blockedUserIDs.contains(user.id) else {
                return nil
            }
            return Self.hsContact(from: user, forcedStatus: "blocked")
        }
    }

    func searchContacts(query: String, limit: Int, session: HSUserSession) async throws -> [HSContact] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return []
        }
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: contactsSearchPayload(query: cleanQuery, limit: limit),
            credentials: credentials
        )
        let payload = try Self.parseContactsFoundResult(result)
        cache(users: payload.users, chats: payload.chats)
        return payload.users.compactMap { user in
            guard payload.resultUserIDs.contains(user.id) else {
                return nil
            }
            return Self.hsContact(from: user, forcedStatus: payload.myResultUserIDs.contains(user.id) ? "contact" : "global")
        }
    }

    func resolveContact(identifier: String, session: HSUserSession) async throws -> HSContact {
        let normalized = Self.normalizedContactIdentifier(identifier)
        guard !normalized.value.isEmpty else {
            throw HSAPIError.server(code: "EMPTY_IDENTIFIER", message: "Please enter a username, phone number, or HSgram link.")
        }
        let credentials = try authorizedAuthKey(for: session)
        let query: Data
        switch normalized.kind {
        case .phone:
            query = contactsResolvePhonePayload(phone: normalized.value)
        case .username:
            query = contactsResolveUsernamePayload(username: normalized.value, referrer: nil)
        }
        let result = try await sendEncryptedRPC(query: query, credentials: credentials)
        let payload = try Self.parseResolvedPeerResult(result)
        cache(users: payload.users, chats: payload.chats)
        guard case let .user(userID) = payload.peer,
              let user = payload.users.first(where: { $0.id == userID }) else {
            throw HSAPIError.server(code: "PEER_NOT_USER", message: "This link resolves to a group or channel, not a private chat.")
        }
        return Self.hsContact(from: user, forcedStatus: nil)
    }

    func addContact(userID: Int64, firstName: String, lastName: String, phone: String, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputUser = try inputUserPayload(userID: userID)
        let result = try await sendEncryptedRPC(
            query: contactsAddContactPayload(user: inputUser, firstName: firstName, lastName: lastName, phone: phone),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func requestContact(userID: Int64, firstName: String, lastName: String, phone: String, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputUser = try inputUserPayload(userID: userID)
        let result = try await sendEncryptedRPC(
            query: contactsRequestContactPayload(user: inputUser, firstName: firstName, lastName: lastName, phone: phone),
            credentials: credentials
        )
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func acceptContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputUser = try inputUserPayload(userID: userID)
        let result = try await sendEncryptedRPC(query: contactsAcceptContactPayload(user: inputUser), credentials: credentials)
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func declineContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputUser = try inputUserPayload(userID: userID)
        let result = try await sendEncryptedRPC(query: contactsDeclineContactPayload(user: inputUser), credentials: credentials)
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func deleteContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputUser = try inputUserPayload(userID: userID)
        let result = try await sendEncryptedRPC(query: contactsDeleteContactsPayload(user: inputUser), credentials: credentials)
        try Self.parseUpdatesSuccess(result)
        return HSMessageAction(ok: true, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func blockContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: userID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(query: contactsBlockPayload(peer: inputPeer), credentials: credentials)
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func unblockContact(userID: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: userID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(query: contactsUnblockPayload(peer: inputPeer), credentials: credentials)
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: userID, pts: nil, ptsCount: nil)
    }

    func accountProfile(session: HSUserSession) async throws -> HSAccountProfile {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: usersGetFullUserPayload(id: inputUserSelfPayload()),
            credentials: credentials
        )
        let payload = try Self.parseUsersUserFullResult(result)
        cache(users: payload.users, chats: [])
        let user = payload.users.first { $0.id == payload.full.id } ?? payload.users.first
        let displayName = user?.title ?? session.displayName
        let parts = Self.displayNameParts(displayName: displayName, email: session.email)
        return HSAccountProfile(
            userID: session.userID,
            displayName: displayName,
            firstName: parts.first,
            lastName: parts.last,
            username: user?.username,
            about: payload.full.about,
            email: session.email
        )
    }

    func updateAccountProfile(displayName: String?, username: String?, about: String?, session: HSUserSession) async throws -> HSAccountProfile {
        let credentials = try authorizedAuthKey(for: session)
        let effectiveDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? displayName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : session.displayName
        let parts = Self.displayNameParts(displayName: effectiveDisplayName, email: session.email)
        var updatedUsername: String?
        if displayName != nil || about != nil {
            let result = try await sendEncryptedRPC(
                query: accountUpdateProfilePayload(displayName: displayName, about: about, fallbackEmail: session.email),
                credentials: credentials
            )
            let user = try Self.parseUserResult(result)
            cache(users: [user], chats: [])
            updatedUsername = user.username
        }
        if let username {
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanUsername.isEmpty {
                let result = try await sendEncryptedRPC(query: accountUpdateUsernamePayload(cleanUsername), credentials: credentials)
                let user = try Self.parseUserResult(result)
                cache(users: [user], chats: [])
                updatedUsername = user.username
            }
        }
        return HSAccountProfile(
            userID: session.userID,
            displayName: effectiveDisplayName,
            firstName: parts.first,
            lastName: parts.last,
            username: updatedUsername ?? username,
            about: about ?? "",
            email: session.email
        )
    }

    func devices(session: HSUserSession) async throws -> [HSDeviceSession] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(query: accountGetAuthorizationsPayload(), credentials: credentials)
        return try Self.parseAuthorizationsResult(result)
    }

    func workspaceSummary(session: HSUserSession) async throws -> HSWorkspaceSummary {
        let credentials = try authorizedAuthKey(for: session)
        async let dialogsTask = dialogs(limit: 80, session: session)
        async let contactsTask = contacts(session: session)
        async let authorizationsTask = sendEncryptedRPC(query: accountGetAuthorizationsPayload(), credentials: credentials)

        let dialogs = try await dialogsTask
        let contacts = try await contactsTask
        let authorizationsData = try await authorizationsTask
        let authorizations = try Self.parseAuthorizationsPayloadResult(authorizationsData)

        return Self.workspaceSummary(
            session: session,
            dialogs: dialogs,
            contacts: contacts,
            activeSessions: max(authorizations.devices.count, 1),
            unconfirmedSessions: authorizations.unconfirmedCount
        )
    }

    func resetDevice(id: Int64, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(query: accountResetAuthorizationPayload(id: id), credentials: credentials)
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: id, pts: nil, ptsCount: nil)
    }

    func deleteAccount(reason: String, password: String?, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let trimmedPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let passwordKDF: HSNativePasswordKDFResult?
        if trimmedPassword.isEmpty {
            passwordKDF = nil
        } else {
            let passwordData = try await sendEncryptedRPC(query: accountGetPasswordPayload(), credentials: credentials)
            let challenge = try Self.parseAccountPasswordResult(passwordData)
            passwordKDF = try HSNativePasswordKDF.result(password: trimmedPassword, challenge: challenge)
        }

        let result = try await sendEncryptedRPC(
            query: accountDeleteAccountPayload(reason: reason, passwordKDF: passwordKDF),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        if ok {
            authorizedAuthKeyQueue.sync {
                _ = authorizedAuthKeysByToken.removeValue(forKey: session.token)
            }
            authKeyStore.delete(session: session)
        }
        return HSMessageAction(ok: ok, messageID: nil, dialogID: nil, pts: nil, ptsCount: nil)
    }

    func trustItems(session: HSUserSession) async throws -> [HSTrustItem] {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(query: accountGetAuthorizationsPayload(), credentials: credentials)
        let payload = try Self.parseAuthorizationsPayloadResult(result)
        return Self.trustItemsFromState(
            activeSessions: max(payload.devices.count, 1),
            unconfirmedSessions: payload.unconfirmedCount,
            trustEvents: 0
        )
    }

    func entitlements(session: HSUserSession) async throws -> [HSEntitlement] {
        _ = try authorizedAuthKey(for: session)
        return Self.serverEntitlements
    }

    func adminTools(session: HSUserSession) async throws -> [HSAdminTool] {
        _ = try authorizedAuthKey(for: session)
        return Self.serverAdminTools
    }

    func registerPushToken(
        token: String,
        tokenType: Int,
        sandbox: Bool,
        otherUserIDs: [Int64],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: accountRegisterDevicePayload(
                token: token,
                tokenType: tokenType,
                sandbox: sandbox,
                otherUserIDs: otherUserIDs
            ),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: session.userID, pts: nil, ptsCount: nil)
    }

    func unregisterPushToken(
        token: String,
        tokenType: Int,
        otherUserIDs: [Int64],
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: accountUnregisterDevicePayload(
                token: token,
                tokenType: tokenType,
                otherUserIDs: otherUserIDs
            ),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: session.userID, pts: nil, ptsCount: nil)
    }

    func privacySettings(session: HSUserSession) async throws -> HSPrivacySettings {
        let credentials = try authorizedAuthKey(for: session)
        var items: [HSSettingsItem] = []
        items.reserveCapacity(hsNativePrivacySpecs.count)
        for spec in hsNativePrivacySpecs {
            let snapshot: HSNativePrivacyRulesSnapshot
            let status: String
            do {
                let result = try await sendEncryptedRPC(
                    query: accountGetPrivacyPayload(key: spec.key),
                    credentials: credentials
                )
                snapshot = try Self.parsePrivacyRulesSnapshotResult(result)
                cache(users: snapshot.users, chats: snapshot.chats)
                status = "active"
            } catch {
                snapshot = HSNativePrivacyRulesSnapshot(
                    value: HSPrivacyRuleValue.serverDefault.label,
                    selection: .serverDefault,
                    exceptions: .empty,
                    users: [],
                    chats: []
                )
                status = "unavailable"
            }
            items.append(Self.privacyItem(spec: spec, snapshot: snapshot, status: status))
        }
        return HSPrivacySettings(items: items)
    }

    func updatePrivacySetting(
        id: String,
        value: HSPrivacyRuleValue,
        exceptions: HSPrivacyRuleExceptions,
        session: HSUserSession
    ) async throws -> HSSettingsItem {
        guard value.isBaseRule else {
            throw HSNativeMTProtoError.malformedPacket("unsupported privacy rule value \(value.rawValue)")
        }
        let spec = try Self.privacySpec(id: id)
        let credentials = try authorizedAuthKey(for: session)
        let result = try await sendEncryptedRPC(
            query: try accountSetPrivacyPayload(key: spec.key, value: value, exceptions: exceptions),
            credentials: credentials
        )
        let snapshot = try Self.parsePrivacyRulesSnapshotResult(result)
        cache(users: snapshot.users, chats: snapshot.chats)
        return Self.privacyItem(spec: spec, snapshot: snapshot, status: "active")
    }

    func notificationSettings(session: HSUserSession) async throws -> HSNotificationSettings {
        let credentials = try authorizedAuthKey(for: session)
        return HSNotificationSettings(
            privateChats: try await notifySettings(scope: .privateChats, credentials: credentials),
            groups: try await notifySettings(scope: .groups, credentials: credentials),
            channels: try await notifySettings(scope: .channels, credentials: credentials)
        )
    }

    func updateNotificationSettings(_ settings: HSNotificationSettings, session: HSUserSession) async throws -> HSNotificationSettings {
        let credentials = try authorizedAuthKey(for: session)
        let updates: [(HSNativeNotifyScope, HSNotifyScopeSettings)] = [
            (.privateChats, settings.privateChats),
            (.groups, settings.groups),
            (.channels, settings.channels)
        ]
        for (scope, value) in updates {
            let result = try await sendEncryptedRPC(
                query: accountUpdateNotifySettingsPayload(scope: scope, settings: value),
                credentials: credentials
            )
            _ = try Self.parseBoolResult(result)
        }
        return try await notificationSettings(session: session)
    }

    func updatePeerNotificationSettings(
        dialogID: Int64,
        muteInterval: Int?,
        showPreviews: Bool = true,
        silent: Bool = false,
        session: HSUserSession
    ) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: accountUpdateNotifySettingsPayload(
                peer: inputPeer,
                settings: HSNotifyScopeSettings(
                    enabled: muteInterval.map { $0 == 0 } ?? true,
                    showPreviews: showPreviews,
                    silent: silent,
                    muteUntil: muteUntilTimestamp(from: muteInterval)
                )
            ),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func reportPeer(dialogID: Int64, reason: HSReportReason, message: String, session: HSUserSession) async throws -> HSMessageAction {
        let credentials = try authorizedAuthKey(for: session)
        let inputPeer = try inputPeerPayload(dialogID: dialogID, sessionUserID: session.userID)
        let result = try await sendEncryptedRPC(
            query: accountReportPeerPayload(peer: inputPeer, reason: reason, message: message),
            credentials: credentials
        )
        let ok = try Self.parseBoolResult(result)
        return HSMessageAction(ok: ok, messageID: nil, dialogID: dialogID, pts: nil, ptsCount: nil)
    }

    func storageSettings(session: HSUserSession) async throws -> HSStorageSettings {
        let catalog = try await assetCatalog(session: session)
        return HSStorageSettings(
            mediaBytes: 0,
            documentBytes: 0,
            cacheBytes: 0,
            otherBytes: 0,
            installedStickerSets: catalog.installedStickers.count,
            featuredStickerSets: catalog.featuredStickers.count,
            availableReactions: catalog.reactions.count,
            autoDownloadWiFi: true,
            autoDownloadCellular: false
        )
    }

    func assetCatalog(session: HSUserSession) async throws -> HSAssetCatalog {
        let credentials = try authorizedAuthKey(for: session)
        let installedData = try await sendEncryptedRPC(
            query: messagesGetAllStickersPayload(hash: 0),
            credentials: credentials
        )
        let featuredData = try await sendEncryptedRPC(
            query: messagesGetFeaturedStickersPayload(hash: 0),
            credentials: credentials
        )
        let reactionsData = try await sendEncryptedRPC(
            query: messagesGetAvailableReactionsPayload(hash: 0),
            credentials: credentials
        )
        return HSAssetCatalog(
            installedStickers: try Self.parseAllStickersResult(installedData),
            featuredStickers: try Self.parseFeaturedStickersResult(featuredData),
            reactions: try Self.parseAvailableReactionsResult(reactionsData)
        )
    }

    private func notifySettings(scope: HSNativeNotifyScope, credentials: HSNativeAuthKeyCredentials) async throws -> HSNotifyScopeSettings {
        let result = try await sendEncryptedRPC(
            query: accountGetNotifySettingsPayload(scope: scope),
            credentials: credentials
        )
        return try Self.parseNotifySettingsResult(result)
    }

    private func muteUntilTimestamp(from muteInterval: Int?) -> Int? {
        guard let muteInterval else {
            return nil
        }
        if muteInterval <= 0 {
            return 0
        }
        if muteInterval >= Int(Int32.max) {
            return Int(Int32.max)
        }
        return Int(Date().timeIntervalSince1970) + muteInterval
    }

    func authSendCodePayload(email: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authSendCode)
        writer.string(email)
        writer.int32(configuration.apiID)
        writer.string(configuration.apiHash)
        writer.constructor(HSNativeMTProtoSchema.codeSettings)
        writer.int32(0)
        return writer.data
    }

    func initConnectionPayload(query: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.initConnection)
        writer.uint32(0)
        writer.int32(configuration.apiID)
        writer.string(configuration.deviceModel)
        writer.string("iOS")
        writer.string("1.0")
        writer.string(Locale.current.language.languageCode?.identifier ?? "en")
        writer.string("")
        writer.string(Locale.current.language.languageCode?.identifier ?? "en")
        writer.raw(query)
        return writer.data
    }

    func invokeWithLayerPayload(query: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.invokeWithLayer)
        writer.int32(configuration.layer)
        writer.raw(query)
        return writer.data
    }

    func authSignInEmailPayload(email: String, phoneCodeHash: String, code: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authSignInEmail)
        writer.int32(1 << 1)
        writer.string(email)
        writer.string(phoneCodeHash)
        writer.constructor(HSNativeMTProtoSchema.emailVerificationCode)
        writer.string(code)
        return writer.data
    }

    func authSignUpPayload(email: String, phoneCodeHash: String, firstName: String, lastName: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authSignUp)
        writer.int32(0)
        writer.string(email)
        writer.string(phoneCodeHash)
        writer.string(firstName)
        writer.string(lastName)
        return writer.data
    }

    func signUpInviteLastNamePayload(inviteCode: String, lastName: String) -> String {
        let payload = [
            "inviteCode": inviteCode.trimmingCharacters(in: .whitespacesAndNewlines),
            "lastName": lastName
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return lastName
        }
        return "__hsinvite__:" + data.base64EncodedString()
    }

    func accountGetPasswordPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountGetPassword)
        return writer.data
    }

    func authCheckPasswordPayload(_ kdf: HSNativePasswordKDFResult) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authCheckPassword)
        writer.raw(inputCheckPasswordSRPPayload(kdf))
        return writer.data
    }

    func inputCheckPasswordSRPPayload(_ kdf: HSNativePasswordKDFResult) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.inputCheckPasswordSRP)
        writer.int64(kdf.id)
        writer.bytes(kdf.a)
        writer.bytes(kdf.m1)
        return writer.data
    }

    func inputCheckPasswordEmptyPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.inputCheckPasswordEmpty)
        return writer.data
    }

    func authRequestPasswordRecoveryPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authRequestPasswordRecovery)
        return writer.data
    }

    func authRecoverPasswordPayload(code: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.authRecoverPassword)
        writer.int32(0)
        writer.string(code)
        return writer.data
    }

    func accountUpdatePasswordSettingsPayload(password: Data, newSettings: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUpdatePasswordSettings)
        writer.raw(password)
        writer.raw(newSettings)
        return writer.data
    }

    func accountConfirmPasswordEmailPayload(code: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountConfirmPasswordEmail)
        writer.string(code)
        return writer.data
    }

    func accountResendPasswordEmailPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountResendPasswordEmail)
        return writer.data
    }

    func accountCancelPasswordEmailPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountCancelPasswordEmail)
        return writer.data
    }

    func accountPasswordInputSettingsPayload(
        newPassword: String?,
        hint: String?,
        recoveryEmail: String?,
        newAlgorithm: HSNativePasswordKDF.Algorithm?
    ) throws -> Data {
        let normalizedHint = hint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedEmail = recoveryEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        var flags: Int32 = 0
        var update: HSNativePasswordUpdateKDFResult?
        if let newPassword, !newPassword.isEmpty {
            guard let newAlgorithm else {
                throw HSAPIError.server(code: "PASSWORD_KDF_ALGO_UNKNOWN", message: "服务端没有返回可用于设置登录密码的 KDF 参数。")
            }
            update = try HSNativePasswordKDF.updateHash(password: newPassword, algorithm: newAlgorithm)
            flags |= 1 << 0
        }
        if !normalizedEmail.isEmpty {
            flags |= 1 << 1
        }

        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountPasswordInputSettings)
        writer.int32(flags)
        if let update {
            writer.raw(passwordKdfAlgoPayload(update.algorithm))
            writer.bytes(update.passwordHash)
            writer.string(normalizedHint)
        }
        if !normalizedEmail.isEmpty {
            writer.string(normalizedEmail)
        }
        return writer.data
    }

    func passwordKdfAlgoPayload(_ algorithm: HSNativePasswordKDF.Algorithm) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.passwordKdfAlgoModPow)
        writer.bytes(algorithm.salt1)
        writer.bytes(algorithm.salt2)
        writer.int32(algorithm.g)
        writer.bytes(algorithm.p)
        return writer.data
    }

    func accountUpdateProfilePayload(displayName: String?, about: String?, fallbackEmail: String) -> Data {
        let parts = Self.displayNameParts(displayName: displayName ?? "", email: fallbackEmail)
        var flags: Int32 = 0
        if displayName != nil {
            flags |= 1 << 0
            flags |= 1 << 1
        }
        if about != nil {
            flags |= 1 << 2
        }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUpdateProfile)
        writer.int32(flags)
        if displayName != nil {
            writer.string(parts.first)
            writer.string(parts.last)
        }
        if let about {
            writer.string(about)
        }
        return writer.data
    }

    func accountUpdateUsernamePayload(_ username: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUpdateUsername)
        writer.string(username)
        return writer.data
    }

    func usersGetFullUserPayload(id: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.usersGetFullUser)
        writer.raw(id)
        return writer.data
    }

    func inputUserSelfPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.inputUserSelf)
        return writer.data
    }

    func accountGetAuthorizationsPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountGetAuthorizations)
        return writer.data
    }

    func accountResetAuthorizationPayload(id: Int64) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountResetAuthorization)
        writer.int64(id)
        return writer.data
    }

    func accountDeleteAccountPayload(reason: String, passwordKDF: HSNativePasswordKDFResult?) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountDeleteAccount)
        writer.int32(passwordKDF == nil ? 0 : 1 << 0)
        writer.string(reason)
        if let passwordKDF {
            writer.constructor(HSNativeMTProtoSchema.inputCheckPasswordSRP)
            writer.int64(passwordKDF.id)
            writer.bytes(passwordKDF.a)
            writer.bytes(passwordKDF.m1)
        }
        return writer.data
    }

    func accountGetPrivacyPayload(key: UInt32) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountGetPrivacy)
        writer.constructor(key)
        return writer.data
    }

    func accountSetPrivacyPayload(
        key: UInt32,
        value: HSPrivacyRuleValue,
        exceptions: HSPrivacyRuleExceptions
    ) throws -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountSetPrivacy)
        writer.constructor(key)
        let rules = try inputPrivacyRulePayloads(for: value, exceptions: exceptions)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(rules.count))
        for rule in rules {
            writer.raw(rule)
        }
        return writer.data
    }

    func accountRegisterDevicePayload(token: String, tokenType: Int, sandbox: Bool, otherUserIDs: [Int64]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountRegisterDevice)
        writer.int32(0)
        writer.int32(Int32(clamping: tokenType))
        writer.string(token)
        writer.constructor(sandbox ? HSNativeMTProtoSchema.boolTrue : HSNativeMTProtoSchema.boolFalse)
        writer.bytes(Data())
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: otherUserIDs.count))
        for userID in otherUserIDs {
            writer.int64(userID)
        }
        return writer.data
    }

    func accountUnregisterDevicePayload(token: String, tokenType: Int, otherUserIDs: [Int64]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUnregisterDevice)
        writer.int32(Int32(clamping: tokenType))
        writer.string(token)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: otherUserIDs.count))
        for userID in otherUserIDs {
            writer.int64(userID)
        }
        return writer.data
    }

    private func accountGetNotifySettingsPayload(scope: HSNativeNotifyScope) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountGetNotifySettings)
        writer.constructor(scope.inputConstructor)
        return writer.data
    }

    private func accountUpdateNotifySettingsPayload(scope: HSNativeNotifyScope, settings: HSNotifyScopeSettings) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUpdateNotifySettings)
        writer.constructor(scope.inputConstructor)
        writer.raw(inputPeerNotifySettingsPayload(settings))
        return writer.data
    }

    private func accountUpdateNotifySettingsPayload(peer: Data, settings: HSNotifyScopeSettings) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountUpdateNotifySettings)
        writer.constructor(HSNativeMTProtoSchema.inputNotifyPeer)
        writer.raw(peer)
        writer.raw(inputPeerNotifySettingsPayload(settings))
        return writer.data
    }

    private func inputPeerNotifySettingsPayload(_ settings: HSNotifyScopeSettings) -> Data {
        var flags: UInt32 = 0
        flags |= 1 << 0
        flags |= 1 << 1
        flags |= 1 << 2

        let muteUntil: Int32
        if settings.enabled {
            muteUntil = 0
        } else if let explicitMuteUntil = settings.muteUntil {
            muteUntil = Int32(clamping: explicitMuteUntil)
        } else {
            let oneYear = Date().addingTimeInterval(365 * 24 * 60 * 60).timeIntervalSince1970
            muteUntil = Int32(clamping: Int(oneYear))
        }

        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.inputPeerNotifySettings)
        writer.int32(Int32(bitPattern: flags))
        writer.constructor(settings.showPreviews ? HSNativeMTProtoSchema.boolTrue : HSNativeMTProtoSchema.boolFalse)
        writer.constructor(settings.silent ? HSNativeMTProtoSchema.boolTrue : HSNativeMTProtoSchema.boolFalse)
        writer.int32(muteUntil)
        return writer.data
    }

    private func accountReportPeerPayload(peer: Data, reason: HSReportReason, message: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.accountReportPeer)
        writer.raw(peer)
        writer.constructor(inputReportReasonConstructor(for: reason))
        writer.string(message)
        return writer.data
    }

    private func inputReportReasonConstructor(for reason: HSReportReason) -> UInt32 {
        switch reason {
        case .spam:
            return HSNativeMTProtoSchema.inputReportReasonSpam
        case .fake:
            return HSNativeMTProtoSchema.inputReportReasonFake
        case .violence:
            return HSNativeMTProtoSchema.inputReportReasonViolence
        case .pornography:
            return HSNativeMTProtoSchema.inputReportReasonPornography
        case .childAbuse:
            return HSNativeMTProtoSchema.inputReportReasonChildAbuse
        case .copyright:
            return HSNativeMTProtoSchema.inputReportReasonCopyright
        case .geoIrrelevant:
            return HSNativeMTProtoSchema.inputReportReasonGeoIrrelevant
        case .illegalDrugs:
            return HSNativeMTProtoSchema.inputReportReasonIllegalDrugs
        case .personalDetails:
            return HSNativeMTProtoSchema.inputReportReasonPersonalDetails
        case .other:
            return HSNativeMTProtoSchema.inputReportReasonOther
        }
    }

    func updatesGetStatePayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.updatesGetState)
        return writer.data
    }

    func updatesGetDifferencePayload(state: HSSyncState, ptsTotalLimit: Int?) -> Data {
        var flags: UInt32 = 0
        if ptsTotalLimit != nil {
            flags |= 1 << 0
        }

        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.updatesGetDifference)
        writer.uint32(flags)
        writer.int32(Int32(clamping: state.pts))
        if flags & (1 << 1) != 0 {
            writer.int32(0)
        }
        if let ptsTotalLimit {
            writer.int32(Int32(clamping: ptsTotalLimit))
        }
        writer.int32(Int32(clamping: state.date))
        writer.int32(Int32(clamping: state.qts))
        if flags & (1 << 2) != 0 {
            writer.int32(0)
        }
        return writer.data
    }

    func messagesGetDialogsPayload(limit: Int, folderID: Int? = nil) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetDialogs)
        var flags: UInt32 = 0
        if folderID != nil {
            flags |= 1 << 1
        }
        writer.int32(Int32(bitPattern: flags))
        if let folderID {
            writer.int32(Int32(clamping: folderID))
        }
        writer.int32(0)
        writer.int32(0)
        writer.constructor(HSNativeMTProtoSchema.inputPeerEmpty)
        writer.int32(Int32(clamping: limit))
        writer.int64(0)
        return writer.data
    }

    func messagesGetDialogFiltersPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetDialogFilters)
        return writer.data
    }

    func messagesUpdateDialogFilterPayload(id: Int, filterPayload: Data?) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesUpdateDialogFilter)
        writer.int32(filterPayload == nil ? 0 : 1)
        writer.int32(Int32(clamping: id))
        if let filterPayload {
            writer.raw(filterPayload)
        }
        return writer.data
    }

    func messagesUpdateDialogFiltersOrderPayload(ids: [Int]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesUpdateDialogFiltersOrder)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: ids.count))
        for id in ids {
            writer.int32(Int32(clamping: id))
        }
        return writer.data
    }

    func messagesToggleDialogFilterTagsPayload(enabled: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesToggleDialogFilterTags)
        writer.constructor(enabled ? HSNativeMTProtoSchema.boolTrue : HSNativeMTProtoSchema.boolFalse)
        return writer.data
    }

    func messagesGetHistoryPayload(peer: Data, beforeID: Int64?, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetHistory)
        writer.raw(peer)
        writer.int32(Int32(clamping: beforeID ?? 0))
        writer.int32(0)
        writer.int32(0)
        writer.int32(Int32(clamping: limit))
        writer.int32(0)
        writer.int32(0)
        writer.int64(0)
        return writer.data
    }

    func messagesGetFullChatPayload(chatID: Int64) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetFullChat)
        writer.int64(chatID)
        return writer.data
    }

    func messagesGetWebPagePreviewPayload(message: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetWebPagePreview)
        writer.int32(0)
        writer.string(message)
        return writer.data
    }

    func messagesSendMessagePayload(peer: Data, text: String, replyToMessageID: Int64?, noWebpage: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSendMessage)
        var flags: Int32 = replyToMessageID == nil ? 0 : 1 << 0
        if noWebpage {
            flags |= 1 << 1
        }
        writer.int32(flags)
        writer.raw(peer)
        if let replyToMessageID {
            writer.constructor(HSNativeMTProtoSchema.inputReplyToMessage)
            writer.int32(0)
            writer.int32(Int32(clamping: replyToMessageID))
        }
        writer.string(text)
        writer.int64(Int64.random(in: Int64.min...Int64.max))
        return writer.data
    }

    func messagesSaveDraftPayload(peer: Data, text: String, replyToMessageID: Int64?, noWebpage: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSaveDraft)
        var flags: Int32 = replyToMessageID == nil ? 0 : 1 << 4
        if noWebpage {
            flags |= 1 << 1
        }
        writer.int32(flags)
        if let replyToMessageID {
            writer.constructor(HSNativeMTProtoSchema.inputReplyToMessage)
            writer.int32(0)
            writer.int32(Int32(clamping: replyToMessageID))
        }
        writer.raw(peer)
        writer.string(text)
        return writer.data
    }

    func messagesGetAllDraftsPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetAllDrafts)
        return writer.data
    }

    func messagesGetAllStickersPayload(hash: Int64) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetAllStickers)
        writer.int64(hash)
        return writer.data
    }

    func messagesGetFeaturedStickersPayload(hash: Int64) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetFeaturedStickers)
        writer.int64(hash)
        return writer.data
    }

    func messagesGetAvailableReactionsPayload(hash: Int32) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetAvailableReactions)
        writer.int32(hash)
        return writer.data
    }

    func messagesReadHistoryPayload(peer: Data, maxMessageID: Int64?) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesReadHistory)
        writer.raw(peer)
        writer.int32(Int32(clamping: maxMessageID ?? 0))
        return writer.data
    }

    func messagesGetPeerDialogsPayload(peer: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetPeerDialogs)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.constructor(HSNativeMTProtoSchema.inputDialogPeer)
        writer.raw(peer)
        return writer.data
    }

    func messagesMarkDialogUnreadPayload(peer: Data, unread: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesMarkDialogUnread)
        writer.int32(unread ? 1 : 0)
        writer.constructor(HSNativeMTProtoSchema.inputDialogPeer)
        writer.raw(peer)
        return writer.data
    }

    func messagesToggleDialogPinPayload(peer: Data, pinned: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesToggleDialogPin)
        writer.int32(pinned ? 1 : 0)
        writer.constructor(HSNativeMTProtoSchema.inputDialogPeer)
        writer.raw(peer)
        return writer.data
    }

    func messagesReorderPinnedDialogsPayload(peers: [Data], folderID: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesReorderPinnedDialogs)
        writer.int32(1)
        writer.int32(Int32(clamping: folderID))
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: peers.count))
        for peer in peers {
            writer.constructor(HSNativeMTProtoSchema.inputDialogPeer)
            writer.raw(peer)
        }
        return writer.data
    }

    func foldersEditPeerFoldersPayload(peer: Data, folderID: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.foldersEditPeerFolders)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.constructor(HSNativeMTProtoSchema.inputFolderPeer)
        writer.raw(peer)
        writer.int32(Int32(clamping: folderID))
        return writer.data
    }

    func messagesEditMessagePayload(peer: Data, messageID: Int64, text: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesEditMessage)
        writer.int32(1 << 11)
        writer.raw(peer)
        writer.int32(Int32(clamping: messageID))
        writer.string(text)
        return writer.data
    }

    func messagesDeleteMessagesPayload(messageID: Int64, revoke: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesDeleteMessages)
        writer.int32(revoke ? 1 : 0)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.int32(Int32(clamping: messageID))
        return writer.data
    }

    func messagesDeleteHistoryPayload(peer: Data, justClear: Bool, revoke: Bool, maxMessageID: Int64?) -> Data {
        var flags: Int32 = 0
        if justClear { flags |= 1 << 0 }
        if revoke { flags |= 1 << 1 }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesDeleteHistory)
        writer.int32(flags)
        writer.raw(peer)
        writer.int32(Int32(clamping: maxMessageID ?? Int64(Int32.max - 1)))
        return writer.data
    }

    func messagesSetTypingPayload(peer: Data, activity: HSInputActivityKind, progress: Int?) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSetTyping)
        writer.int32(0)
        writer.raw(peer)
        writeSendMessageAction(activity, progress: progress, writer: &writer)
        return writer.data
    }

    func writeSendMessageAction(_ activity: HSInputActivityKind, progress: Int?, writer: inout HSTLWriter) {
        switch activity {
        case .cancel:
            writer.constructor(HSNativeMTProtoSchema.sendMessageCancelAction)
        case .typing:
            writer.constructor(HSNativeMTProtoSchema.sendMessageTypingAction)
        case .recordingVoice:
            writer.constructor(HSNativeMTProtoSchema.sendMessageRecordAudioAction)
        case .recordingVideo:
            writer.constructor(HSNativeMTProtoSchema.sendMessageRecordVideoAction)
        case .uploadingFile:
            writer.constructor(HSNativeMTProtoSchema.sendMessageUploadDocumentAction)
            writer.int32(Int32(clamping: progress ?? 0))
        case .uploadingPhoto:
            writer.constructor(HSNativeMTProtoSchema.sendMessageUploadPhotoAction)
            writer.int32(Int32(clamping: progress ?? 0))
        case .uploadingVideo:
            writer.constructor(HSNativeMTProtoSchema.sendMessageUploadVideoAction)
            writer.int32(Int32(clamping: progress ?? 0))
        case .uploadingVoice:
            writer.constructor(HSNativeMTProtoSchema.sendMessageUploadAudioAction)
            writer.int32(Int32(clamping: progress ?? 0))
        case .uploadingInstantVideo:
            writer.constructor(HSNativeMTProtoSchema.sendMessageUploadRoundAction)
            writer.int32(Int32(clamping: progress ?? 0))
        case .choosingSticker:
            writer.constructor(HSNativeMTProtoSchema.sendMessageChooseStickerAction)
        }
    }

    func messagesForwardMessagesPayload(fromPeer: Data, messageID: Int64, toPeer: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesForwardMessages)
        writer.int32(0)
        writer.raw(fromPeer)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.int32(Int32(clamping: messageID))
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.int64(Int64.random(in: Int64.min...Int64.max))
        writer.raw(toPeer)
        return writer.data
    }

    func messagesSearchGlobalPayload(query: String, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSearchGlobal)
        writer.int32(0)
        writer.string(query)
        writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterEmpty)
        writer.int32(0)
        writer.int32(0)
        writer.int32(0)
        writer.constructor(HSNativeMTProtoSchema.inputPeerEmpty)
        writer.int32(0)
        writer.int32(Int32(clamping: limit))
        return writer.data
    }

    func messagesSearchPayload(peer: Data, query: String, filter: HSSharedMediaFilter?, offsetID: Int64?, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSearch)
        writer.int32(0)
        writer.raw(peer)
        writer.string(query)
        if let filter {
            writeMessagesFilter(filter, writer: &writer)
        } else {
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterEmpty)
        }
        writer.int32(0)
        writer.int32(Int32.max - 1)
        writer.int32(Int32(clamping: offsetID ?? 0))
        writer.int32(0)
        writer.int32(Int32(clamping: limit))
        writer.int32(Int32.max - 1)
        writer.int32(0)
        writer.int64(0)
        return writer.data
    }

    func messagesGetSearchCountersPayload(peer: Data, filters: [HSSharedMediaFilter]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesGetSearchCounters)
        writer.int32(0)
        writer.raw(peer)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: filters.count))
        for filter in filters {
            writeMessagesFilter(filter, writer: &writer)
        }
        return writer.data
    }

    func writeMessagesFilter(_ filter: HSSharedMediaFilter, writer: inout HSTLWriter) {
        switch filter {
        case .media:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterPhotoVideo)
        case .files:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterDocument)
        case .links:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterUrl)
        case .gifs:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterGif)
        case .voice:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterRoundVoice)
        case .music:
            writer.constructor(HSNativeMTProtoSchema.inputMessagesFilterMusic)
        }
    }

    func messagesSendReactionPayload(peer: Data, messageID: Int64, reaction: String, big: Bool) -> Data {
        var flags: Int32 = 1 << 0
        if big { flags |= 1 << 1 }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSendReaction)
        writer.int32(flags)
        writer.raw(peer)
        writer.int32(Int32(clamping: messageID))
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.constructor(HSNativeMTProtoSchema.reactionEmoji)
        writer.string(reaction)
        return writer.data
    }

    func messagesSendMediaPayload(peer: Data, media: Data, caption: String, replyToMessageID: Int64?) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesSendMedia)
        writer.int32(replyToMessageID == nil ? 0 : 1 << 0)
        writer.raw(peer)
        if let replyToMessageID {
            writer.constructor(HSNativeMTProtoSchema.inputReplyToMessage)
            writer.int32(0)
            writer.int32(Int32(clamping: replyToMessageID))
        }
        writer.raw(media)
        writer.string(caption)
        writer.int64(Int64.random(in: Int64.min...Int64.max))
        return writer.data
    }

    func uploadSaveFilePartPayload(fileID: Int64, partIndex: Int, bytes: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.uploadSaveFilePart)
        writer.int64(fileID)
        writer.int32(Int32(clamping: partIndex))
        writer.bytes(bytes)
        return writer.data
    }

    func uploadSaveBigFilePartPayload(fileID: Int64, partIndex: Int, partCount: Int, bytes: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.uploadSaveBigFilePart)
        writer.int64(fileID)
        writer.int32(Int32(clamping: partIndex))
        writer.int32(Int32(clamping: partCount))
        writer.bytes(bytes)
        return writer.data
    }

    func uploadGetFilePayload(location: HSMessageMediaLocation, offset: Int64, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.uploadGetFile)
        writer.int32(0)
        writer.raw(inputFileLocationPayload(location))
        writer.int64(offset)
        writer.int32(Int32(clamping: limit))
        return writer.data
    }

    func inputFileLocationPayload(_ location: HSMessageMediaLocation) -> Data {
        var writer = HSTLWriter()
        switch location.kind {
        case .photo:
            writer.constructor(HSNativeMTProtoSchema.inputPhotoFileLocation)
        case .document:
            writer.constructor(HSNativeMTProtoSchema.inputDocumentFileLocation)
        }
        writer.int64(location.id)
        writer.int64(location.accessHash)
        writer.bytes(location.fileReference)
        writer.string(location.thumbnailSize)
        return writer.data
    }

    func inputFilePayload(fileID: Int64, partCount: Int, fileName: String, data: Data, isBig: Bool) -> Data {
        var writer = HSTLWriter()
        if isBig {
            writer.constructor(HSNativeMTProtoSchema.inputFileBig)
            writer.int64(fileID)
            writer.int32(Int32(clamping: partCount))
            writer.string(Self.safeFileName(fileName))
        } else {
            writer.constructor(HSNativeMTProtoSchema.inputFile)
            writer.int64(fileID)
            writer.int32(Int32(clamping: partCount))
            writer.string(Self.safeFileName(fileName))
            writer.string(Self.md5Hex(data))
        }
        return writer.data
    }

    func photosUploadProfilePhotoPayload(file: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.photosUploadProfilePhoto)
        writer.int32(1 << 0)
        writer.raw(file)
        return writer.data
    }

    func photosUpdateProfilePhotoPayload(id: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.photosUpdateProfilePhoto)
        writer.int32(0)
        writer.raw(id)
        return writer.data
    }

    func inputPhotoEmptyPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.inputPhotoEmpty)
        return writer.data
    }

    func inputMediaPayload(file: Data, fileName: String, mimeType: String, mediaKind: String, duration: Double?, waveform: Data?) -> Data {
        let normalizedKind = mediaKind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedMime = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isAnimatedImage = normalizedMime == "image/gif"
        let isPhoto = !isAnimatedImage && (normalizedKind == "photo" || normalizedMime.hasPrefix("image/"))
        let isVideo = normalizedKind == "video" || normalizedMime.hasPrefix("video/")
        let isVoice = normalizedKind == "voice"
        let isAudio = isVoice || normalizedKind == "audio" || normalizedMime.hasPrefix("audio/")
        var writer = HSTLWriter()
        if isPhoto {
            writer.constructor(HSNativeMTProtoSchema.inputMediaUploadedPhoto)
            writer.int32(0)
            writer.raw(file)
        } else {
            writer.constructor(HSNativeMTProtoSchema.inputMediaUploadedDocument)
            writer.int32(isVideo || isAudio ? 0 : 1 << 4)
            writer.raw(file)
            writer.string(normalizedMime.isEmpty ? "application/octet-stream" : normalizedMime)
            writer.constructor(HSNativeMTProtoSchema.vector)
            writer.int32(1 + (isVideo ? 1 : 0) + (isAnimatedImage ? 1 : 0) + (isAudio ? 1 : 0))
            writer.constructor(HSNativeMTProtoSchema.documentAttributeFilename)
            writer.string(Self.safeFileName(fileName))
            if isAnimatedImage {
                writer.constructor(HSNativeMTProtoSchema.documentAttributeAnimated)
            }
            if isAudio {
                writer.constructor(HSNativeMTProtoSchema.documentAttributeAudio)
                let voiceWaveform = isVoice == true && waveform?.isEmpty == false ? waveform : nil
                writer.int32((isVoice ? 1 << 10 : 0) | (voiceWaveform == nil ? 0 : 1 << 2))
                writer.int32(Int32(clamping: Int((duration ?? 0).rounded())))
                if let voiceWaveform {
                    writer.bytes(voiceWaveform)
                }
            }
            if isVideo {
                writer.constructor(HSNativeMTProtoSchema.documentAttributeVideo)
                writer.int32(1 << 1)
                writer.double(0)
                writer.int32(0)
                writer.int32(0)
            }
        }
        return writer.data
    }

    func contactsGetContactsPayload() -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsGetContacts)
        writer.int64(0)
        return writer.data
    }

    func contactsGetBlockedPayload(offset: Int, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsGetBlocked)
        writer.int32(0)
        writer.int32(Int32(clamping: offset))
        writer.int32(Int32(clamping: limit))
        return writer.data
    }

    func contactsSearchPayload(query: String, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsSearch)
        writer.string(query)
        writer.int32(Int32(clamping: limit))
        return writer.data
    }

    func contactsResolveUsernamePayload(username: String, referrer: String?) -> Data {
        var flags: Int32 = 0
        if referrer != nil {
            flags |= 1 << 0
        }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsResolveUsername)
        writer.int32(flags)
        writer.string(username)
        if let referrer {
            writer.string(referrer)
        }
        return writer.data
    }

    func contactsResolvePhonePayload(phone: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsResolvePhone)
        writer.string(phone)
        return writer.data
    }

    func contactsAddContactPayload(user: Data, firstName: String, lastName: String, phone: String) -> Data {
        var normalizedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedPhone.isEmpty && !normalizedPhone.hasPrefix("+") {
            normalizedPhone = "+\(normalizedPhone)"
        }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsAddContact)
        writer.int32(0)
        writer.raw(user)
        writer.string(firstName)
        writer.string(lastName)
        writer.string(normalizedPhone)
        return writer.data
    }

    func contactsRequestContactPayload(user: Data, firstName: String, lastName: String, phone: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsRequestContact)
        writer.raw(user)
        writer.string(firstName)
        writer.string(lastName)
        writer.string(phone)
        return writer.data
    }

    func contactsAcceptContactPayload(user: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsAcceptContact)
        writer.raw(user)
        return writer.data
    }

    func contactsDeclineContactPayload(user: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsDeclineContact)
        writer.raw(user)
        return writer.data
    }

    func contactsDeleteContactsPayload(user: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsDeleteContacts)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(1)
        writer.raw(user)
        return writer.data
    }

    func contactsBlockPayload(peer: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsBlock)
        writer.int32(0)
        writer.raw(peer)
        return writer.data
    }

    func contactsUnblockPayload(peer: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.contactsUnblock)
        writer.int32(0)
        writer.raw(peer)
        return writer.data
    }

    func channelsCreateChannelPayload(title: String, about: String, isBroadcast: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsCreateChannel)
        writer.int32(isBroadcast ? 1 << 0 : 1 << 1)
        writer.string(title)
        writer.string(about)
        return writer.data
    }

    func channelsGetFullChannelPayload(channel: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsGetFullChannel)
        writer.raw(channel)
        return writer.data
    }

    func channelsEditTitlePayload(channel: Data, title: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsEditTitle)
        writer.raw(channel)
        writer.string(title)
        return writer.data
    }

    func messagesEditChatAboutPayload(peer: Data, about: String) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesEditChatAbout)
        writer.raw(peer)
        writer.string(about)
        return writer.data
    }

    func channelsLeaveChannelPayload(channel: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsLeaveChannel)
        writer.raw(channel)
        return writer.data
    }

    func channelsGetParticipantsPayload(channel: Data, offset: Int, limit: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsGetParticipants)
        writer.raw(channel)
        writer.constructor(HSNativeMTProtoSchema.channelParticipantsRecent)
        writer.int32(Int32(clamping: offset))
        writer.int32(Int32(clamping: limit))
        writer.int64(0)
        return writer.data
    }

    func channelsInviteToChannelPayload(channel: Data, users: [Data]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsInviteToChannel)
        writer.raw(channel)
        writeVector(users, writer: &writer)
        return writer.data
    }

    func channelsEditAdminPayload(channel: Data, user: Data, rights: HSSupergroupAdminRights, rank: String?) -> Data {
        let trimmedRank = rank?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsEditAdmin)
        writer.raw(channel)
        writer.raw(user)
        writeChatAdminRights(rights, writer: &writer)
        writer.string(trimmedRank)
        return writer.data
    }

    func channelsEditBannedPayload(channel: Data, participant: Data, rights: HSSupergroupBannedRights) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsEditBanned)
        writer.raw(channel)
        writer.raw(participant)
        writeChatBannedRights(rights, writer: &writer)
        return writer.data
    }

    func channelsDeleteParticipantHistoryPayload(channel: Data, participant: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsDeleteParticipantHistory)
        writer.raw(channel)
        writer.raw(participant)
        return writer.data
    }

    func channelsToggleSlowModePayload(channel: Data, seconds: Int) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsToggleSlowMode)
        writer.raw(channel)
        writer.int32(Int32(clamping: seconds))
        return writer.data
    }

    func channelsToggleParticipantsHiddenPayload(channel: Data, enabled: Bool) -> Data {
        channelBoolPayload(HSNativeMTProtoSchema.channelsToggleParticipantsHidden, channel: channel, enabled: enabled)
    }

    func channelsTogglePreHistoryHiddenPayload(channel: Data, enabled: Bool) -> Data {
        channelBoolPayload(HSNativeMTProtoSchema.channelsTogglePreHistoryHidden, channel: channel, enabled: enabled)
    }

    func channelsToggleJoinToSendPayload(channel: Data, enabled: Bool) -> Data {
        channelBoolPayload(HSNativeMTProtoSchema.channelsToggleJoinToSend, channel: channel, enabled: enabled)
    }

    func channelsToggleJoinRequestPayload(channel: Data, enabled: Bool) -> Data {
        channelBoolPayload(HSNativeMTProtoSchema.channelsToggleJoinRequest, channel: channel, enabled: enabled)
    }

    func messagesUpdatePinnedMessagePayload(peer: Data, messageID: Int64, silent: Bool, unpin: Bool) -> Data {
        var flags: Int32 = 0
        if silent { flags |= 1 << 0 }
        if unpin { flags |= 1 << 1 }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesUpdatePinnedMessage)
        writer.int32(flags)
        writer.raw(peer)
        writer.int32(Int32(clamping: messageID))
        return writer.data
    }

    func channelsExportMessageLinkPayload(channel: Data, messageID: Int64) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsExportMessageLink)
        writer.int32(0)
        writer.raw(channel)
        writer.int32(Int32(clamping: messageID))
        return writer.data
    }

    func messagesExportChatInvitePayload(peer: Data, title: String?, expireDate: Int?, usageLimit: Int?, requestNeeded: Bool) -> Data {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        var flags: Int32 = 0
        if expireDate != nil { flags |= 1 << 0 }
        if usageLimit != nil { flags |= 1 << 1 }
        if requestNeeded { flags |= 1 << 3 }
        if cleanTitle?.isEmpty == false { flags |= 1 << 4 }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.messagesExportChatInvite)
        writer.int32(flags)
        writer.raw(peer)
        if let expireDate {
            writer.int32(Int32(clamping: expireDate))
        }
        if let usageLimit {
            writer.int32(Int32(clamping: usageLimit))
        }
        if let cleanTitle, !cleanTitle.isEmpty {
            writer.string(cleanTitle)
        }
        return writer.data
    }

    func channelsGetAdminLogPayload(channel: Data, query: String?, admins: [Data], limit: Int) -> Data {
        let cleanQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var flags: Int32 = 0
        if !admins.isEmpty { flags |= 1 << 1 }
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.channelsGetAdminLog)
        writer.int32(flags)
        writer.raw(channel)
        writer.string(cleanQuery)
        if !admins.isEmpty {
            writeVector(admins, writer: &writer)
        }
        writer.int64(0)
        writer.int64(0)
        writer.int32(Int32(clamping: limit))
        return writer.data
    }

    private func channelBoolPayload(_ constructor: UInt32, channel: Data, enabled: Bool) -> Data {
        var writer = HSTLWriter()
        writer.constructor(constructor)
        writer.raw(channel)
        writer.constructor(enabled ? HSNativeMTProtoSchema.boolTrue : HSNativeMTProtoSchema.boolFalse)
        return writer.data
    }

    private func writeVector(_ items: [Data], writer: inout HSTLWriter) {
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: items.count))
        for item in items {
            writer.raw(item)
        }
    }

    private func writeChatAdminRights(_ rights: HSSupergroupAdminRights, writer: inout HSTLWriter) {
        var flags: Int32 = 0
        if rights.changeInfo { flags |= 1 << 0 }
        if rights.postMessages { flags |= 1 << 1 }
        if rights.editMessages { flags |= 1 << 2 }
        if rights.deleteMessages { flags |= 1 << 3 }
        if rights.banUsers { flags |= 1 << 4 }
        if rights.inviteUsers { flags |= 1 << 5 }
        if rights.pinMessages { flags |= 1 << 7 }
        if rights.addAdmins { flags |= 1 << 9 }
        if rights.anonymous { flags |= 1 << 10 }
        if rights.manageCall { flags |= 1 << 11 }
        if rights.other { flags |= 1 << 12 }
        if rights.manageTopics { flags |= 1 << 13 }
        if rights.postStories { flags |= 1 << 14 }
        if rights.editStories { flags |= 1 << 15 }
        if rights.deleteStories { flags |= 1 << 16 }
        writer.constructor(HSNativeMTProtoSchema.chatAdminRights)
        writer.int32(flags)
    }

    private func writeChatBannedRights(_ rights: HSSupergroupBannedRights, writer: inout HSTLWriter) {
        var flags: Int32 = 0
        if rights.viewMessages { flags |= 1 << 0 }
        if rights.sendMessages { flags |= 1 << 1 }
        if rights.sendMedia { flags |= 1 << 2 }
        if rights.sendStickers { flags |= 1 << 3 }
        if rights.sendGifs { flags |= 1 << 4 }
        if rights.sendGames { flags |= 1 << 5 }
        if rights.sendInline { flags |= 1 << 6 }
        if rights.embedLinks { flags |= 1 << 7 }
        if rights.sendPolls { flags |= 1 << 8 }
        if rights.changeInfo { flags |= 1 << 10 }
        if rights.inviteUsers { flags |= 1 << 15 }
        if rights.pinMessages { flags |= 1 << 17 }
        if rights.manageTopics { flags |= 1 << 18 }
        if rights.sendPhotos { flags |= 1 << 19 }
        if rights.sendVideos { flags |= 1 << 20 }
        if rights.sendRoundvideos { flags |= 1 << 21 }
        if rights.sendAudios { flags |= 1 << 22 }
        if rights.sendVoices { flags |= 1 << 23 }
        if rights.sendDocs { flags |= 1 << 24 }
        if rights.sendPlain { flags |= 1 << 25 }
        writer.constructor(HSNativeMTProtoSchema.chatBannedRights)
        writer.int32(flags)
        writer.int32(Int32(clamping: max(0, rights.untilDate)))
    }

    private func uploadMediaFile(
        data: Data,
        fileName: String,
        credentials: HSNativeAuthKeyCredentials,
        progress: ((HSMediaTransferProgress) -> Void)?
    ) async throws -> Data {
        let partSize = 512 * 1024
        let fileID = Int64.random(in: Int64.min...Int64.max)
        let partCount = max(1, Int(ceil(Double(data.count) / Double(partSize))))
        let isBig = data.count > 10 * 1024 * 1024
        let totalBytes = Int64(data.count)
        progress?(HSMediaTransferProgress(completedBytes: 0, totalBytes: totalBytes))
        for partIndex in 0..<partCount {
            try Task.checkCancellation()
            let start = partIndex * partSize
            let end = min(start + partSize, data.count)
            let part = data.subdata(in: start..<end)
            let payload = isBig
                ? uploadSaveBigFilePartPayload(fileID: fileID, partIndex: partIndex, partCount: partCount, bytes: part)
                : uploadSaveFilePartPayload(fileID: fileID, partIndex: partIndex, bytes: part)
            let ok = try Self.parseBoolResult(try await sendEncryptedRPC(query: payload, credentials: credentials))
            guard ok else {
                throw HSAPIError.server(code: "MEDIA_UPLOAD_FAILED", message: "媒体分片上传失败，请重试。")
            }
            progress?(HSMediaTransferProgress(completedBytes: Int64(end), totalBytes: totalBytes))
        }
        return inputFilePayload(fileID: fileID, partCount: partCount, fileName: fileName, data: data, isBig: isBig)
    }

    private func sendEncryptedRPC(query: Data, authKey: HSNativeAuthKeyMaterial) async throws -> Data {
        try await sendEncryptedRPC(query: query, credentials: authKey.credentials)
    }

    private func sendEncryptedRPC(query: Data, credentials: HSNativeAuthKeyCredentials) async throws -> Data {
        try await transport.withSession(timeout: 24) { session in
            try await self.sendEncryptedRPC(
                body: self.invokeWithLayerPayload(query: self.initConnectionPayload(query: query)),
                credentials: credentials,
                sessionID: Self.randomInt64(),
                on: session
            )
        }
    }

    private func signUp(
        email: String,
        transactionID: String,
        displayName: String,
        inviteCode: String,
        authKey: HSNativeAuthKeyMaterial
    ) async throws -> HSUserSession {
        let parts = Self.displayNameParts(displayName: displayName, email: email)
        let result = try await sendEncryptedRPC(
            query: authSignUpPayload(
                email: email,
                phoneCodeHash: transactionID,
                firstName: parts.first,
                lastName: signUpInviteLastNamePayload(inviteCode: inviteCode, lastName: parts.last)
            ),
            authKey: authKey
        )
        return try Self.parseAuthorizationResult(result, email: email, fallbackName: displayName)
    }

    func probeServer() async throws -> HSNativeMTProtoProbe {
        let nonce = try Self.secureRandom(count: 16)
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.reqPqMulti)
        writer.raw(nonce)
        let response = try await transport.roundTrip(plainBody: writer.data)
        return try Self.parseResPQ(response: response, expectedNonce: nonce)
    }

    func requestServerDHParams() async throws -> HSNativeServerDHMaterial {
        try await transport.withSession { session in
            try await self.requestServerDHParams(on: session)
        }
    }

    func createAuthKey() async throws -> HSNativeAuthKeyMaterial {
        try await transport.withSession { session in
            let serverDHMaterial = try await self.requestServerDHParams(on: session)
            return try await self.completeAuthKeyHandshake(serverDHMaterial, on: session)
        }
    }

    private func failUntilEncryptedTransportIsReady<T>(method: String) async throws -> T {
        let authKey = try await createAuthKey()
        throw HSNativeMTProtoError.encryptedTransportPending(
            method: method,
            authKeyID: authKey.authKeyID,
            serverSalt: authKey.serverSalt
        )
    }

    private func storePendingAuthKey(_ authKey: HSNativeAuthKeyMaterial, email: String, transactionID: String?) {
        let emailKey = Self.normalizedEmailKey(email)
        pendingAuthKeyQueue.sync {
            pendingAuthKeysByEmail[emailKey] = authKey
            if let transactionID, !transactionID.isEmpty {
                pendingAuthKeysByTransaction[Self.pendingTransactionKey(email: email, transactionID: transactionID)] = authKey
            }
        }
    }

    private func pendingAuthKey(email: String, transactionID: String) async throws -> HSNativeAuthKeyMaterial {
        let authKey = pendingAuthKeyQueue.sync {
            pendingAuthKeysByTransaction[Self.pendingTransactionKey(email: email, transactionID: transactionID)]
                ?? pendingAuthKeysByEmail[Self.normalizedEmailKey(email)]
        }
        if let authKey {
            return authKey
        }
        return try await createAuthKey()
    }

    private func clearPendingAuthKey(email: String, transactionID: String) {
        pendingAuthKeyQueue.sync {
            pendingAuthKeysByEmail.removeValue(forKey: Self.normalizedEmailKey(email))
            pendingAuthKeysByTransaction.removeValue(forKey: Self.pendingTransactionKey(email: email, transactionID: transactionID))
        }
    }

    private func storeAuthorizedAuthKey(_ credentials: HSNativeAuthKeyCredentials, session: HSUserSession) {
        authorizedAuthKeyQueue.sync {
            authorizedAuthKeysByToken[session.token] = credentials
        }
        authKeyStore.save(credentials, session: session)
    }

    private func authorizedAuthKey(for session: HSUserSession) throws -> HSNativeAuthKeyCredentials {
        if let credentials = authorizedAuthKeyQueue.sync(execute: { authorizedAuthKeysByToken[session.token] }) {
            return credentials
        }
        if let credentials = authKeyStore.load(session: session) {
            authorizedAuthKeyQueue.sync {
                authorizedAuthKeysByToken[session.token] = credentials
            }
            return credentials
        }
        throw HSAPIError.server(
            code: "SESSION_RELOGIN_REQUIRED",
            message: "本地没有这个账号的 MTProto auth_key，请重新登录后继续。"
        )
    }

    private func cache(users: [HSNativeParsedUser], chats: [HSNativeParsedChat]) {
        peerCacheQueue.sync {
            for user in users {
                guard let accessHash = user.accessHash else {
                    continue
                }
                var writer = HSTLWriter()
                writer.constructor(HSNativeMTProtoSchema.inputPeerUser)
                writer.int64(user.id)
                writer.int64(accessHash)
                var userWriter = HSTLWriter()
                userWriter.constructor(HSNativeMTProtoSchema.inputUser)
                userWriter.int64(user.id)
                userWriter.int64(accessHash)
                cachedPeersByDialogID[user.id] = HSNativeCachedPeer(
                    dialogID: user.id,
                    inputPeerPayload: writer.data,
                    inputChannelPayload: nil,
                    inputUserPayload: userWriter.data,
                    title: user.title,
                    isGroupLike: false
                )
            }
            for chat in chats {
                var writer = HSTLWriter()
                var inputChannelPayload: Data?
                switch chat.peer {
                case .chat(let chatID):
                    writer.constructor(HSNativeMTProtoSchema.inputPeerChat)
                    writer.int64(chatID)
                case .channel(let channelID):
                    guard let accessHash = chat.accessHash else {
                        continue
                    }
                    writer.constructor(HSNativeMTProtoSchema.inputPeerChannel)
                    writer.int64(channelID)
                    writer.int64(accessHash)
                    var channelWriter = HSTLWriter()
                    channelWriter.constructor(HSNativeMTProtoSchema.inputChannel)
                    channelWriter.int64(channelID)
                    channelWriter.int64(accessHash)
                    inputChannelPayload = channelWriter.data
                case .user:
                    continue
                }
                cachedPeersByDialogID[chat.peer.dialogID] = HSNativeCachedPeer(
                    dialogID: chat.peer.dialogID,
                    inputPeerPayload: writer.data,
                    inputChannelPayload: inputChannelPayload,
                    inputUserPayload: nil,
                    title: chat.title,
                    isGroupLike: chat.isGroupLike
                )
                if let group = Self.supergroup(from: chat) {
                    cachedGroupsByDialogID[group.id] = group
                }
            }
        }
    }

    private func inputUserPayload(userID: Int64) throws -> Data {
        if let payload = peerCacheQueue.sync(execute: { cachedPeersByDialogID[userID]?.inputUserPayload }) {
            return payload
        }
        throw HSAPIError.server(
            code: "USER_NOT_RESOLVED",
            message: "这个联系人还没有 access_hash，请先刷新联系人或搜索一次再操作。"
        )
    }

    private func inputPeerPayload(dialogID: Int64, sessionUserID: Int64?) throws -> Data {
        if let sessionUserID, dialogID == sessionUserID {
            var writer = HSTLWriter()
            writer.constructor(HSNativeMTProtoSchema.inputPeerSelf)
            return writer.data
        }
        if dialogID < 0, dialogID > HSNativePeer.channelDialogPrefix {
            var writer = HSTLWriter()
            writer.constructor(HSNativeMTProtoSchema.inputPeerChat)
            writer.int64(-dialogID)
            return writer.data
        }
        if let peer = peerCacheQueue.sync(execute: { cachedPeersByDialogID[dialogID] }) {
            return peer.inputPeerPayload
        }
        throw HSAPIError.server(
            code: "PEER_NOT_RESOLVED",
            message: "这个会话还没有 access_hash，请先刷新会话列表或联系人后再操作。"
        )
    }

    private func inputPeerPayload(filterPeer peer: HSChatListFilterPeer, sessionUserID: Int64) throws -> Data {
        if peer.kind == .user, peer.peerID == sessionUserID, peer.accessHash == nil {
            var writer = HSTLWriter()
            writer.constructor(HSNativeMTProtoSchema.inputPeerSelf)
            return writer.data
        }
        if let accessHash = peer.accessHash {
            var writer = HSTLWriter()
            switch peer.kind {
            case .user:
                writer.constructor(HSNativeMTProtoSchema.inputPeerUser)
                writer.int64(peer.peerID)
                writer.int64(accessHash)
                return writer.data
            case .channel:
                writer.constructor(HSNativeMTProtoSchema.inputPeerChannel)
                writer.int64(peer.peerID)
                writer.int64(accessHash)
                return writer.data
            case .chat:
                break
            }
        }
        if peer.kind == .chat {
            var writer = HSTLWriter()
            writer.constructor(HSNativeMTProtoSchema.inputPeerChat)
            writer.int64(peer.peerID)
            return writer.data
        }
        return try inputPeerPayload(dialogID: peer.dialogID, sessionUserID: sessionUserID)
    }

    private func dialogFilterPayload(_ filter: HSChatListFilter, sessionUserID: Int64) throws -> Data {
        var writer = HSTLWriter()
        if filter.isShared {
            writer.constructor(HSNativeMTProtoSchema.dialogFilterChatlist)
        } else {
            writer.constructor(HSNativeMTProtoSchema.dialogFilter)
        }

        var flags = UInt32(bitPattern: filter.categories.rawValue)
        if filter.excludeMuted { flags |= 1 << 11 }
        if filter.excludeRead { flags |= 1 << 12 }
        if filter.excludeArchived { flags |= 1 << 13 }
        if filter.emoticon != nil { flags |= 1 << 25 }
        if filter.hasSharedLinks { flags |= 1 << 26 }
        if filter.color != nil { flags |= 1 << 27 }
        if !filter.titleAnimationsEnabled { flags |= 1 << 28 }

        writer.int32(Int32(bitPattern: flags))
        writer.int32(Int32(clamping: filter.id))
        writer.constructor(HSNativeMTProtoSchema.textWithEntities)
        writer.string(filter.title)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(0)
        if let emoticon = filter.emoticon {
            writer.string(emoticon)
        }
        if let color = filter.color {
            writer.int32(Int32(clamping: color))
        }
        try writeInputPeerVector(filter.pinnedPeers, writer: &writer, sessionUserID: sessionUserID)
        try writeInputPeerVector(filter.includePeers.filter { !filter.pinnedPeers.contains($0) }, writer: &writer, sessionUserID: sessionUserID)
        if !filter.isShared {
            try writeInputPeerVector(filter.excludePeers, writer: &writer, sessionUserID: sessionUserID)
        }
        return writer.data
    }

    private func writeInputPeerVector(_ peers: [HSChatListFilterPeer], writer: inout HSTLWriter, sessionUserID: Int64) throws {
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(clamping: peers.count))
        for peer in peers {
            writer.raw(try inputPeerPayload(filterPeer: peer, sessionUserID: sessionUserID))
        }
    }

    private func inputChannelPayload(dialogID: Int64) throws -> Data {
        if let payload = peerCacheQueue.sync(execute: { cachedPeersByDialogID[dialogID]?.inputChannelPayload }) {
            return payload
        }
        throw HSAPIError.server(
            code: "CHANNEL_NOT_RESOLVED",
            message: "这个会话不是可管理的超级群或频道，请先刷新会话列表后再操作。"
        )
    }

    private static func normalizedEmailKey(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func pendingTransactionKey(email: String, transactionID: String) -> String {
        "\(normalizedEmailKey(email))|\(transactionID)"
    }

    private func requestServerDHParams(on session: HSNativeMTProtoIntermediateSession) async throws -> HSNativeServerDHMaterial {
        let nonce = try Self.secureRandom(count: 16)
        var reqPQ = HSTLWriter()
        reqPQ.constructor(HSNativeMTProtoSchema.reqPqMulti)
        reqPQ.raw(nonce)
        let resPQEnvelope = try await session.sendPlainBody(reqPQ.data)
        let probe = try Self.parseResPQ(response: resPQEnvelope, expectedNonce: nonce)

        let (p, q) = try Self.factorPQ(probe.pq)
        let newNonce = try Self.secureRandom(count: 32)
        let fingerprint = try Self.selectedFingerprint(from: probe.publicKeyFingerprints)
        let innerData = Self.pqInnerData(
            pq: probe.pq,
            p: p,
            q: q,
            nonce: probe.nonce,
            serverNonce: probe.serverNonce,
            newNonce: newNonce
        )
        let encryptedData = try await encryptedPQInnerDataWithRetry(innerData)

        var reqDH = HSTLWriter()
        reqDH.constructor(HSNativeMTProtoSchema.reqDHParams)
        reqDH.raw(probe.nonce)
        reqDH.raw(probe.serverNonce)
        reqDH.bytes(p)
        reqDH.bytes(q)
        reqDH.int64(fingerprint)
        reqDH.bytes(encryptedData)

        let serverDHEnvelope = try await session.sendPlainBody(reqDH.data)
        return try Self.parseServerDHParams(
            response: serverDHEnvelope,
            probe: probe,
            newNonce: newNonce,
            p: p,
            q: q
        )
    }

    private func completeAuthKeyHandshake(
        _ material: HSNativeServerDHMaterial,
        on session: HSNativeMTProtoIntermediateSession
    ) async throws -> HSNativeAuthKeyMaterial {
        try Self.validateServerDHMaterial(material)

        let b = try Self.secureRandom(count: 256)
        let gB = try HSNativeMTProtoBigInt.modExp(
            base: Data([UInt8(material.g)]),
            exponent: b,
            modulus: material.dhPrime
        )
        let authKey = try HSNativeMTProtoBigInt.modExp(
            base: material.gA,
            exponent: b,
            modulus: material.dhPrime,
            outputLength: 256
        )

        let clientInnerData = Self.clientDHInnerData(material: material, gB: gB)
        let encryptedData = try Self.encryptedClientDHInnerData(
            clientInnerData,
            newNonce: material.newNonce,
            serverNonce: material.probe.serverNonce
        )

        var request = HSTLWriter()
        request.constructor(HSNativeMTProtoSchema.setClientDHParams)
        request.raw(material.probe.nonce)
        request.raw(material.probe.serverNonce)
        request.bytes(encryptedData)

        let response = try await session.sendPlainBody(request.data)
        try Self.parseSetClientDHParamsAnswer(
            response: response,
            material: material,
            authKey: authKey
        )

        return HSNativeAuthKeyMaterial(
            serverDHMaterial: material,
            authKey: authKey,
            authKeyID: try HSNativeMTProtoCrypto.authKeyID(authKey: authKey),
            serverSalt: try HSNativeMTProtoCrypto.serverSalt(
                newNonce: material.newNonce,
                serverNonce: material.probe.serverNonce
            ),
            timeDifference: material.serverTime - Int32(Date().timeIntervalSince1970)
        )
    }

    private func sendEncryptedRPC(
        body: Data,
        authKey: HSNativeAuthKeyMaterial,
        sessionID: Int64,
        on session: HSNativeMTProtoIntermediateSession
    ) async throws -> Data {
        try await sendEncryptedRPC(
            body: body,
            credentials: authKey.credentials,
            sessionID: sessionID,
            on: session
        )
    }

    private func sendEncryptedRPC(
        body: Data,
        credentials: HSNativeAuthKeyCredentials,
        sessionID: Int64,
        on session: HSNativeMTProtoIntermediateSession
    ) async throws -> Data {
        let requestMessageID = Self.encryptedMessageID(timeDifference: credentials.timeDifference)
        let payload = try Self.encryptedMessagePayload(
            authKeyID: credentials.authKeyID,
            authKey: credentials.authKey,
            serverSalt: credentials.serverSalt,
            sessionID: sessionID,
            messageID: requestMessageID,
            seqNo: 1,
            body: body
        )

        var pendingBodies: [Data] = []
        var responsePayload: Data? = try await session.sendRawPayload(payload, timeout: 24)
        for _ in 0..<12 {
            if pendingBodies.isEmpty {
                let payload: Data
                if let currentPayload = responsePayload {
                    payload = currentPayload
                    responsePayload = nil
                } else {
                    payload = try await session.receiveRawPayload(timeout: 24)
                }
                let message = try Self.decryptEncryptedMessagePayload(
                    payload,
                    authKeyID: credentials.authKeyID,
                    authKey: credentials.authKey
                )
                pendingBodies.append(message.body)
            }

            var bodyReader = HSTLReader(data: pendingBodies.removeFirst())
            let constructor = try bodyReader.uint32()

            switch constructor {
            case HSNativeMTProtoSchema.newSessionCreated:
                _ = try bodyReader.int64()
                _ = try bodyReader.int64()
                _ = try bodyReader.int64()
            case HSNativeMTProtoSchema.msgContainer:
                let count = Int(try bodyReader.int32())
                guard count >= 0 else {
                    throw HSNativeMTProtoError.malformedPacket("negative encrypted message container count")
                }
                for _ in 0..<count {
                    _ = try bodyReader.int64()
                    _ = try bodyReader.int32()
                    let bytes = Int(try bodyReader.int32())
                    pendingBodies.append(try bodyReader.raw(count: bytes))
                }
            case HSNativeMTProtoSchema.msgsAck:
                try Self.consumeMsgIDVector(reader: &bodyReader)
            case HSNativeMTProtoSchema.badMsgNotification:
                let badMsgID = try bodyReader.int64()
                let badSeqNo = try bodyReader.int32()
                let errorCode = try bodyReader.int32()
                throw HSNativeMTProtoError.malformedPacket("bad_msg_notification bad_msg_id=\(badMsgID) seq_no=\(badSeqNo) error_code=\(errorCode)")
            case HSNativeMTProtoSchema.badServerSalt:
                let badMsgID = try bodyReader.int64()
                let badSeqNo = try bodyReader.int32()
                let errorCode = try bodyReader.int32()
                let newServerSalt = try bodyReader.int64()
                throw HSNativeMTProtoError.malformedPacket("bad_server_salt bad_msg_id=\(badMsgID) seq_no=\(badSeqNo) error_code=\(errorCode) new_server_salt=\(newServerSalt)")
            case HSNativeMTProtoSchema.rpcResult:
                let reqMsgID = try bodyReader.int64()
                guard reqMsgID == requestMessageID else {
                    continue
                }
                return bodyReader.remainingData()
            default:
                throw HSNativeMTProtoError.malformedPacket("unexpected encrypted response constructor 0x\(String(constructor, radix: 16))")
            }
        }

        throw HSNativeMTProtoError.malformedPacket("encrypted RPC response did not include rpc_result")
    }

    private func encryptedPQInnerDataWithRetry(_ innerData: Data) async throws -> Data {
        var lastError: Error?
        for _ in 0..<32 {
            do {
                let padding = try Self.secureRandom(count: 192 - innerData.count)
                let tempKey = try Self.secureRandom(count: 32)
                return try HSNativeMTProtoCrypto.encryptPQInnerData(innerData, randomPadding: padding, tempKey: tempKey)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? HSNativeMTProtoError.malformedPacket("RSA padding retry failed")
    }

    private static func pqInnerData(pq: Data, p: Data, q: Data, nonce: Data, serverNonce: Data, newNonce: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.pQInnerData)
        writer.bytes(pq)
        writer.bytes(p)
        writer.bytes(q)
        writer.raw(nonce)
        writer.raw(serverNonce)
        writer.raw(newNonce)
        return writer.data
    }

    private static func clientDHInnerData(material: HSNativeServerDHMaterial, gB: Data) -> Data {
        var writer = HSTLWriter()
        writer.constructor(HSNativeMTProtoSchema.clientDHInnerData)
        writer.raw(material.probe.nonce)
        writer.raw(material.probe.serverNonce)
        writer.int64(0)
        writer.bytes(gB)
        return writer.data
    }

    private static func encryptedClientDHInnerData(_ innerData: Data, newNonce: Data, serverNonce: Data) throws -> Data {
        let aes = try HSNativeMTProtoCrypto.temporaryAESKeyAndIV(newNonce: newNonce, serverNonce: serverNonce)
        var payload = HSNativeMTProtoCrypto.sha1(innerData)
        payload.append(innerData)
        let paddingLength = (16 - (payload.count % 16)) % 16
        if paddingLength > 0 {
            payload.append(try secureRandom(count: paddingLength))
        }
        return try HSNativeMTProtoCrypto.aesIGE(
            payload,
            key: aes.key,
            iv: aes.iv,
            operation: CCOperation(kCCEncrypt)
        )
    }

    private static func encryptedMessagePayload(
        authKeyID: Int64,
        authKey: Data,
        serverSalt: Int64,
        sessionID: Int64,
        messageID: Int64,
        seqNo: Int32,
        body: Data
    ) throws -> Data {
        guard authKey.count == 256 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto encrypted message requires 256-byte auth_key.")
        }

        var rawWriter = HSTLWriter()
        rawWriter.int64(serverSalt)
        rawWriter.int64(sessionID)
        rawWriter.int64(messageID)
        rawWriter.int32(seqNo)
        rawWriter.int32(Int32(body.count))
        rawWriter.raw(body)

        var rawData = rawWriter.data
        var paddingLength = rawData.count % 16
        if paddingLength != 0 {
            paddingLength = 16 - paddingLength
        }
        if paddingLength < 12 {
            paddingLength += 16
        }
        rawData.append(try secureRandom(count: paddingLength))

        let msgKeyLarge = HSNativeMTProtoCrypto.sha256(authKey.subdata(in: 88..<120) + rawData)
        let msgKey = msgKeyLarge.subdata(in: 8..<24)
        let aes = try messageAESKeyAndIV(authKey: authKey, msgKey: msgKey, incoming: false)
        let encryptedData = try HSNativeMTProtoCrypto.aesIGE(
            rawData,
            key: aes.key,
            iv: aes.iv,
            operation: CCOperation(kCCEncrypt)
        )

        var envelope = HSTLWriter()
        envelope.int64(authKeyID)
        envelope.raw(msgKey)
        envelope.raw(encryptedData)
        return envelope.data
    }

    private static func decryptEncryptedMessagePayload(
        _ payload: Data,
        authKeyID: Int64,
        authKey: Data
    ) throws -> HSNativeEncryptedMessage {
        guard authKey.count == 256 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto encrypted message requires 256-byte auth_key.")
        }

        var envelope = HSTLReader(data: payload)
        let responseAuthKeyID = try envelope.int64()
        guard responseAuthKeyID == authKeyID else {
            throw HSNativeMTProtoError.malformedPacket("encrypted response auth_key_id mismatch")
        }
        let msgKey = try envelope.raw(count: 16)
        let encryptedData = envelope.remainingData()
        let aes = try messageAESKeyAndIV(authKey: authKey, msgKey: msgKey, incoming: true)
        let rawData = try HSNativeMTProtoCrypto.aesIGE(
            encryptedData,
            key: aes.key,
            iv: aes.iv,
            operation: CCOperation(kCCDecrypt)
        )

        guard rawData.count >= 32 else {
            throw HSNativeMTProtoError.malformedPacket("encrypted response payload is too short")
        }
        let declaredBodyLength = Int(UInt32(rawData[28])
            | (UInt32(rawData[29]) << 8)
            | (UInt32(rawData[30]) << 16)
            | (UInt32(rawData[31]) << 24))
        guard declaredBodyLength > 0, 32 + declaredBodyLength <= rawData.count else {
            throw HSNativeMTProtoError.malformedPacket("encrypted response body length is invalid: \(declaredBodyLength)")
        }
        let paddingLength = rawData.count - 32 - declaredBodyLength
        guard paddingLength >= 12, paddingLength <= 1024 else {
            throw HSNativeMTProtoError.malformedPacket("encrypted response padding length is invalid: \(paddingLength)")
        }

        let expectedMsgKey = HSNativeMTProtoCrypto
            .sha256(authKey.subdata(in: 96..<128) + rawData)
            .subdata(in: 8..<24)
        guard expectedMsgKey == msgKey else {
            throw HSNativeMTProtoError.malformedPacket("encrypted response msg_key mismatch")
        }

        var reader = HSTLReader(data: rawData)
        let salt = try reader.int64()
        let sessionID = try reader.int64()
        let messageID = try reader.int64()
        let seqNo = try reader.int32()
        let bodyLength = Int(try reader.int32())
        let body = try reader.raw(count: bodyLength)
        return HSNativeEncryptedMessage(
            salt: salt,
            sessionID: sessionID,
            messageID: messageID,
            seqNo: seqNo,
            body: body
        )
    }

    private static func messageAESKeyAndIV(authKey: Data, msgKey: Data, incoming: Bool) throws -> (key: Data, iv: Data) {
        guard authKey.count == 256, msgKey.count == 16 else {
            throw HSNativeMTProtoCryptoError.badLength("MTProto message AES derivation requires 256-byte auth_key and 16-byte msg_key.")
        }
        let x = incoming ? 8 : 0
        let sha256A = HSNativeMTProtoCrypto.sha256(msgKey + authKey.subdata(in: x..<(x + 36)))
        let sha256B = HSNativeMTProtoCrypto.sha256(authKey.subdata(in: (40 + x)..<(76 + x)) + msgKey)

        var key = Data()
        key.append(sha256A.subdata(in: 0..<8))
        key.append(sha256B.subdata(in: 8..<24))
        key.append(sha256A.subdata(in: 24..<32))

        var iv = Data()
        iv.append(sha256B.subdata(in: 0..<8))
        iv.append(sha256A.subdata(in: 8..<24))
        iv.append(sha256B.subdata(in: 24..<32))
        return (key, iv)
    }

    private static func parseAuthSentCodeResult(_ result: Data, fallbackEmail: String) throws -> HSEmailStartResponse {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.authSentCode:
            let flags = try reader.uint32()
            let typeInfo = try parseSentCodeTypeInfo(reader: &reader, fallbackEmail: fallbackEmail)
            let phoneCodeHash = try reader.string()
            if flags & (1 << 1) != 0 {
                _ = try reader.uint32()
            }
            if flags & (1 << 2) != 0 {
                _ = try reader.int32()
            }
            return HSEmailStartResponse(
                transactionID: phoneCodeHash,
                emailPattern: typeInfo.emailPattern,
                codeLength: typeInfo.codeLength
            )
        case HSNativeMTProtoSchema.authSentCodeSuccess:
            return HSEmailStartResponse(
                transactionID: "",
                emailPattern: maskedEmail(fallbackEmail),
                codeLength: 0
            )
        case HSNativeMTProtoSchema.authSentCodePaymentRequired,
            HSNativeMTProtoSchema.authSentCodePaymentRequiredV2,
            HSNativeMTProtoSchema.authSentCodePaymentRequiredV3:
            throw HSAPIError.server(code: "AUTH_PAYMENT_REQUIRED", message: "该账号需要完成付费验证后才能继续登录。")
        default:
            throw HSNativeMTProtoError.malformedPacket("expected auth.sentCode, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePasswordRecoveryResult(_ result: Data) throws -> HSPasswordRecoveryResponse {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.authPasswordRecovery:
            return HSPasswordRecoveryResponse(
                emailPattern: try reader.string(),
                codeLength: 6
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected auth.PasswordRecovery, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAuthorizationResult(_ result: Data, email: String, fallbackName: String) throws -> HSUserSession {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.authAuthorizationSignUpRequired:
            let flags = try reader.uint32()
            let termsOfService = flags & 1 != 0 ? try parseTermsOfService(reader: &reader) : nil
            throw HSAPIError.signUpRequired(termsOfService: termsOfService)
        case HSNativeMTProtoSchema.authAuthorization:
            let flags = try reader.uint32()
            if flags & (1 << 1) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 0) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 2) != 0 {
                _ = try reader.bytes()
            }
            return try parseUserSession(reader: &reader, email: email, fallbackName: fallbackName)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected auth.Authorization, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseTermsOfService(reader: inout HSTLReader) throws -> HSTermsOfService {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.helpTermsOfService else {
            throw HSNativeMTProtoError.malformedPacket("expected help.TermsOfService, got 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let id = try parseDataJSON(reader: &reader)
        let text = try reader.string()
        try skipObjectVector(reader: &reader, name: "MessageEntity")
        let minAgeConfirm = flags & (1 << 1) != 0 ? Int(try reader.int32()) : nil
        return HSTermsOfService(
            id: id,
            text: text,
            minAgeConfirm: minAgeConfirm,
            isPopup: flags & 1 != 0
        )
    }

    private static func parseUserResult(_ result: Data) throws -> HSNativeParsedUser {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        default:
            reader.rewindUInt32()
            return try parseUserSummary(reader: &reader)
        }
    }

    private static func parseAccountPasswordResult(_ result: Data) throws -> HSNativePasswordChallenge {
        let info = try parseAccountPasswordInfo(result)
        guard let challenge = info.currentChallenge else {
            throw HSAPIError.server(code: "INTERNAL_NO_PASSWORD", message: "服务端没有返回完整的 SRP 密码挑战。")
        }
        return challenge
    }

    private static func parseAccountPasswordInfo(_ result: Data) throws -> HSNativeAccountPasswordInfo {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.accountPassword:
            let flags = try reader.uint32()
            var currentAlgo: HSNativePasswordKDF.Algorithm?
            var srpB: Data?
            var srpID: Int64?
            if flags & (1 << 2) != 0 {
                currentAlgo = try parsePasswordKdfAlgo(reader: &reader, allowUnknown: false)
                srpB = try reader.bytes()
                srpID = try reader.int64()
            }
            let hint = try readOptionalString(reader: &reader, flags: flags, bit: 3)
            let pendingEmailPattern = try readOptionalString(reader: &reader, flags: flags, bit: 4)
            let newAlgorithm = try parsePasswordKdfAlgo(reader: &reader, allowUnknown: true)
            try skipSecurePasswordKdfAlgo(reader: &reader)
            _ = try reader.bytes()
            if flags & (1 << 5) != 0 {
                _ = try reader.int32()
            }
            let loginEmailPattern = try readOptionalString(reader: &reader, flags: flags, bit: 6)

            let challenge: HSNativePasswordChallenge?
            if let currentAlgo, let srpB, let srpID {
                challenge = HSNativePasswordChallenge(
                    salt1: currentAlgo.salt1,
                    salt2: currentAlgo.salt2,
                    g: currentAlgo.g,
                    p: currentAlgo.p,
                    srpB: srpB,
                    srpID: srpID,
                    hint: hint
                )
            } else {
                challenge = nil
            }
            return HSNativeAccountPasswordInfo(
                settings: HSLoginPasswordSettings(
                    hasPassword: flags & (1 << 2) != 0,
                    hasRecovery: flags & (1 << 0) != 0,
                    hint: hint,
                    pendingEmailPattern: pendingEmailPattern,
                    loginEmailPattern: loginEmailPattern
                ),
                currentChallenge: challenge,
                newAlgorithm: newAlgorithm
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected account.Password, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDialogsResult(_ result: Data) throws -> HSNativeDialogsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesDialogs:
            let dialogs = try parseVector(reader: &reader, elementName: "Dialog", parseDialog)
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeDialogsPayload(dialogs: dialogs, messages: messages, chats: chats, users: users)
        case HSNativeMTProtoSchema.messagesDialogsSlice:
            _ = try reader.int32()
            let dialogs = try parseVector(reader: &reader, elementName: "Dialog", parseDialog)
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeDialogsPayload(dialogs: dialogs, messages: messages, chats: chats, users: users)
        case HSNativeMTProtoSchema.messagesDialogsNotModified:
            _ = try reader.int32()
            return HSNativeDialogsPayload(dialogs: [], messages: [], chats: [], users: [])
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.Dialogs, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePeerDialogsResult(_ result: Data) throws -> HSNativeDialogsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesPeerDialogs:
            let dialogs = try parseVector(reader: &reader, elementName: "Dialog", parseDialog)
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            _ = try parseSyncState(reader: &reader)
            return HSNativeDialogsPayload(dialogs: dialogs, messages: messages, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.PeerDialogs, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDialogFiltersResult(_ result: Data, sessionUserID: Int64) throws -> HSChatListFiltersState {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesDialogFilters:
            let flags = try reader.uint32()
            let filters = try parseVector(reader: &reader, elementName: "DialogFilter") { reader in
                try parseDialogFilter(reader: &reader, sessionUserID: sessionUserID)
            }
            return HSChatListFiltersState(tagsEnabled: flags & 1 != 0, filters: filters)
        case HSNativeMTProtoSchema.vector:
            let count = Int(try reader.int32())
            guard count >= 0 else {
                throw HSNativeMTProtoError.malformedPacket("negative DialogFilter vector count")
            }
            var filters: [HSChatListFilter] = []
            filters.reserveCapacity(count)
            for _ in 0..<count {
                filters.append(try parseDialogFilter(reader: &reader, sessionUserID: sessionUserID))
            }
            return HSChatListFiltersState(tagsEnabled: false, filters: filters)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.DialogFilters, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseSyncStateResult(_ result: Data) throws -> HSSyncState {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updatesState:
            reader.rewindUInt32()
            return try parseSyncState(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected updates.State, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseSyncDifferenceResult(_ result: Data, previousState: HSSyncState) throws -> HSNativeSyncDifferencePayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updatesDifferenceEmpty:
            let date = try reader.int32()
            let seq = try reader.int32()
            let state = HSSyncState(
                pts: previousState.pts,
                qts: previousState.qts,
                date: Int(date),
                seq: Int(seq),
                unreadCount: previousState.unreadCount
            )
            return HSNativeSyncDifferencePayload(
                state: state,
                messages: [],
                affectedDialogIDs: [],
                readOutboxMaxIDsByDialogID: [:],
                inputActivities: [],
                affectsAllDialogs: false,
                chats: [],
                users: [],
                isTooLong: false,
                isSlice: false
            )
        case HSNativeMTProtoSchema.updatesDifference, HSNativeMTProtoSchema.updatesDifferenceSlice:
            let newMessages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            try skipEncryptedMessageVector(reader: &reader)
            let updates = try parseVector(reader: &reader, elementName: "Update", parseDifferenceUpdate)
            let updateMessages = updates.compactMap(\.message)
            let affectedDialogIDs = Array(Set(updates.flatMap(\.affectedDialogIDs))).sorted()
            let inputActivities = updates.compactMap(\.inputActivity)
            var readOutboxMaxIDsByDialogID: [Int64: Int64] = [:]
            for update in updates {
                for (dialogID, maxID) in update.readOutboxMaxIDsByDialogID {
                    readOutboxMaxIDsByDialogID[dialogID] = max(readOutboxMaxIDsByDialogID[dialogID] ?? 0, maxID)
                }
            }
            let affectsAllDialogs = updates.contains { $0.affectsAllDialogs }
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let state = try parseSyncState(reader: &reader)
            return HSNativeSyncDifferencePayload(
                state: state,
                messages: newMessages + updateMessages,
                affectedDialogIDs: affectedDialogIDs,
                readOutboxMaxIDsByDialogID: readOutboxMaxIDsByDialogID,
                inputActivities: inputActivities,
                affectsAllDialogs: affectsAllDialogs,
                chats: chats,
                users: users,
                isTooLong: false,
                isSlice: constructor == HSNativeMTProtoSchema.updatesDifferenceSlice
            )
        case HSNativeMTProtoSchema.updatesDifferenceTooLong:
            let pts = try reader.int32()
            let state = HSSyncState(
                pts: Int(pts),
                qts: previousState.qts,
                date: previousState.date,
                seq: previousState.seq,
                unreadCount: previousState.unreadCount
            )
            return HSNativeSyncDifferencePayload(
                state: state,
                messages: [],
                affectedDialogIDs: [],
                readOutboxMaxIDsByDialogID: [:],
                inputActivities: [],
                affectsAllDialogs: true,
                chats: [],
                users: [],
                isTooLong: true,
                isSlice: false
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected updates.Difference, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseSyncState(reader: inout HSTLReader) throws -> HSSyncState {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.updatesState else {
            throw HSNativeMTProtoError.malformedPacket("expected updates.State, got 0x\(String(constructor, radix: 16))")
        }
        let pts = try reader.int32()
        let qts = try reader.int32()
        let date = try reader.int32()
        let seq = try reader.int32()
        let unreadCount = try reader.int32()
        return HSSyncState(
            pts: Int(pts),
            qts: Int(qts),
            date: Int(date),
            seq: Int(seq),
            unreadCount: Int(unreadCount)
        )
    }

    private static func parseMessagesResult(_ result: Data) throws -> HSNativeMessagesPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesMessages:
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            try skipEmptyVector(reader: &reader, name: "ForumTopic")
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeMessagesPayload(messages: messages, chats: chats, users: users)
        case HSNativeMTProtoSchema.messagesMessagesSlice:
            let flags = try reader.uint32()
            _ = try reader.int32()
            if flags & (1 << 0) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 2) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 3) != 0 {
                try skipUnsupportedObject(reader: &reader, name: "SearchPostsFlood")
            }
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            try skipEmptyVector(reader: &reader, name: "ForumTopic")
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeMessagesPayload(messages: messages, chats: chats, users: users)
        case HSNativeMTProtoSchema.messagesChannelMessages:
            let flags = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & (1 << 2) != 0 {
                _ = try reader.int32()
            }
            let messages = try parseVector(reader: &reader, elementName: "Message", parseMessage)
            try skipEmptyVector(reader: &reader, name: "ForumTopic")
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeMessagesPayload(messages: messages, chats: chats, users: users)
        case HSNativeMTProtoSchema.messagesMessagesNotModified:
            _ = try reader.int32()
            return HSNativeMessagesPayload(messages: [], chats: [], users: [])
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.Messages, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseSearchCountersResult(_ result: Data) throws -> [HSSharedMediaCounter] {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.vector:
            let count = Int(try reader.int32())
            guard count >= 0 else {
                throw HSNativeMTProtoError.malformedPacket("negative SearchCounter vector count")
            }
            var counters: [HSSharedMediaCounter] = []
            counters.reserveCapacity(count)
            for _ in 0..<count {
                let itemConstructor = try reader.uint32()
                guard itemConstructor == HSNativeMTProtoSchema.messagesSearchCounter else {
                    throw HSNativeMTProtoError.malformedPacket("unsupported SearchCounter constructor 0x\(String(itemConstructor, radix: 16))")
                }
                _ = try reader.int32()
                let filterConstructor = try reader.uint32()
                guard let filter = sharedMediaFilter(fromMessagesFilterConstructor: filterConstructor) else {
                    throw HSNativeMTProtoError.malformedPacket("unsupported SearchCounter filter constructor 0x\(String(filterConstructor, radix: 16))")
                }
                let rawCount = try reader.int32()
                counters.append(HSSharedMediaCounter(filter: filter, count: max(0, Int(rawCount))))
            }
            return counters
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported messages.getSearchCounters result constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func sharedMediaFilter(fromMessagesFilterConstructor constructor: UInt32) -> HSSharedMediaFilter? {
        switch constructor {
        case HSNativeMTProtoSchema.inputMessagesFilterPhotoVideo:
            return .media
        case HSNativeMTProtoSchema.inputMessagesFilterDocument:
            return .files
        case HSNativeMTProtoSchema.inputMessagesFilterUrl:
            return .links
        case HSNativeMTProtoSchema.inputMessagesFilterGif:
            return .gifs
        case HSNativeMTProtoSchema.inputMessagesFilterRoundVoice:
            return .voice
        case HSNativeMTProtoSchema.inputMessagesFilterMusic:
            return .music
        default:
            return nil
        }
    }

    private static func parseUsersUserFullResult(_ result: Data) throws -> HSNativeParsedUserFullPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.usersUserFull:
            let full = try parseUserFullSummary(reader: &reader)
            _ = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeParsedUserFullPayload(full: full, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected users.UserFull, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseUserFullSummary(reader: inout HSTLReader) throws -> HSNativeParsedUserFull {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.userFull:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let id = try reader.int64()
            let about = flags & (1 << 1) == 0 ? "" : try reader.string()
            try skipPeerSettings(reader: &reader)
            if flags & (1 << 21) != 0 { try skipPhoto(reader: &reader) }
            if flags & (1 << 2) != 0 { try skipPhoto(reader: &reader) }
            if flags & (1 << 22) != 0 { try skipPhoto(reader: &reader) }
            try skipPeerNotifySettings(reader: &reader)
            if flags & (1 << 3) != 0 { try skipBotInfo(reader: &reader) }
            if flags & (1 << 6) != 0 { _ = try reader.int32() }
            _ = try reader.int32()
            if flags & (1 << 11) != 0 { _ = try reader.int32() }
            if flags & (1 << 14) != 0 { _ = try reader.int32() }
            if flags & (1 << 15) != 0 { try skipChatTheme(reader: &reader) }
            if flags & (1 << 16) != 0 { _ = try reader.string() }
            if flags & (1 << 17) != 0 { try skipChatAdminRights(reader: &reader) }
            if flags & (1 << 18) != 0 { try skipChatAdminRights(reader: &reader) }
            if flags & (1 << 24) != 0 { try skipWallPaper(reader: &reader) }
            if flags & (1 << 25) != 0 { try skipPeerStories(reader: &reader) }
            if flags2 & (1 << 0) != 0 { try skipBusinessWorkHours(reader: &reader) }
            if flags2 & (1 << 1) != 0 { try skipBusinessLocation(reader: &reader) }
            if flags2 & (1 << 2) != 0 { try skipBusinessGreetingMessage(reader: &reader) }
            if flags2 & (1 << 3) != 0 { try skipBusinessAwayMessage(reader: &reader) }
            if flags2 & (1 << 4) != 0 { try skipBusinessIntro(reader: &reader) }
            if flags2 & (1 << 5) != 0 { try skipBirthday(reader: &reader) }
            if flags2 & (1 << 6) != 0 {
                _ = try reader.int64()
                _ = try reader.int32()
            }
            if flags2 & (1 << 8) != 0 { _ = try reader.int32() }
            if flags2 & (1 << 11) != 0 { try skipStarRefProgram(reader: &reader) }
            if flags2 & (1 << 12) != 0 { try skipBotVerification(reader: &reader) }
            if flags2 & (1 << 14) != 0 { _ = try reader.int64() }
            if flags2 & (1 << 15) != 0 { try skipDisallowedGiftsSettings(reader: &reader) }
            if flags2 & (1 << 17) != 0 { try skipStarsRating(reader: &reader) }
            if flags2 & (1 << 18) != 0 {
                try skipStarsRating(reader: &reader)
                _ = try reader.int32()
            }
            if flags2 & (1 << 20) != 0 { try skipProfileTab(reader: &reader) }
            if flags2 & (1 << 21) != 0 { try skipDocument(reader: &reader) }
            if flags2 & (1 << 22) != 0 { try skipTextWithEntities(reader: &reader) }
            return HSNativeParsedUserFull(id: id, about: about)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported UserFull constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChatFullResult(_ result: Data) throws -> HSNativeChatFullPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesChatFull:
            let full = try parseChatFullSummary(reader: &reader)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeChatFullPayload(full: full, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.ChatFull, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChatFullSummary(reader: inout HSTLReader) throws -> HSNativeParsedChatFull {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatFull:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let about = try reader.string()
            let memberCount = try parseChatParticipantsCount(reader: &reader)
            if flags & (1 << 2) != 0 {
                try skipPhoto(reader: &reader)
            }
            try skipPeerNotifySettings(reader: &reader)
            if flags & (1 << 13) != 0 {
                try skipExportedChatInvite(reader: &reader)
            }
            if flags & (1 << 3) != 0 {
                try skipObjectVector(reader: &reader, name: "BotInfo")
            }
            if flags & (1 << 6) != 0 { _ = try reader.int32() }
            if flags & (1 << 11) != 0 { _ = try reader.int32() }
            if flags & (1 << 12) != 0 { try skipInputGroupCall(reader: &reader) }
            if flags & (1 << 14) != 0 { _ = try reader.int32() }
            if flags & (1 << 15) != 0 { _ = try parsePeer(reader: &reader) }
            if flags & (1 << 16) != 0 { _ = try reader.string() }
            let pendingRequests = flags & (1 << 17) == 0 ? nil : Int(try reader.int32())
            if flags & (1 << 17) != 0 { try skipInt64Vector(reader: &reader) }
            if flags & (1 << 18) != 0 { try skipChatReactions(reader: &reader) }
            if flags & (1 << 20) != 0 { _ = try reader.int32() }
            return HSNativeParsedChatFull(
                peer: .chat(id),
                about: about,
                memberCount: memberCount,
                pendingRequests: pendingRequests,
                isMegagroup: false,
                isBroadcast: false
            )
        case HSNativeMTProtoSchema.channelFull:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let id = try reader.int64()
            let about = try reader.string()
            let memberCount = flags & 1 == 0 ? nil : Int(try reader.int32())
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
            if flags & (1 << 2) != 0 {
                _ = try reader.int32()
                _ = try reader.int32()
            }
            if flags & (1 << 13) != 0 { _ = try reader.int32() }
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            try skipPhoto(reader: &reader)
            try skipPeerNotifySettings(reader: &reader)
            if flags & (1 << 23) != 0 { try skipExportedChatInvite(reader: &reader) }
            try skipObjectVector(reader: &reader, name: "BotInfo")
            if flags & (1 << 4) != 0 {
                _ = try reader.int64()
                _ = try reader.int32()
            }
            if flags & (1 << 5) != 0 { _ = try reader.int32() }
            if flags & (1 << 8) != 0 { try skipStickerSet(reader: &reader) }
            if flags & (1 << 9) != 0 { _ = try reader.int32() }
            if flags & (1 << 11) != 0 { _ = try reader.int32() }
            if flags & (1 << 14) != 0 { _ = try reader.int64() }
            if flags & (1 << 15) != 0 { try skipChannelLocation(reader: &reader) }
            if flags & (1 << 17) != 0 { _ = try reader.int32() }
            if flags & (1 << 18) != 0 { _ = try reader.int32() }
            if flags & (1 << 12) != 0 { _ = try reader.int32() }
            _ = try reader.int32()
            if flags & (1 << 21) != 0 { try skipInputGroupCall(reader: &reader) }
            if flags & (1 << 24) != 0 { _ = try reader.int32() }
            if flags & (1 << 25) != 0 { _ = try parseStringVector(reader: &reader) }
            if flags & (1 << 26) != 0 { _ = try parsePeer(reader: &reader) }
            if flags & (1 << 27) != 0 { _ = try reader.string() }
            let pendingRequests = flags & (1 << 28) == 0 ? nil : Int(try reader.int32())
            if flags & (1 << 28) != 0 { try skipInt64Vector(reader: &reader) }
            if flags & (1 << 29) != 0 { _ = try parsePeer(reader: &reader) }
            if flags & (1 << 30) != 0 { try skipChatReactions(reader: &reader) }
            if flags2 & (1 << 13) != 0 { _ = try reader.int32() }
            if flags2 & (1 << 4) != 0 { try skipPeerStories(reader: &reader) }
            if flags2 & (1 << 7) != 0 { try skipWallPaper(reader: &reader) }
            if flags2 & (1 << 8) != 0 { _ = try reader.int32() }
            if flags2 & (1 << 9) != 0 { _ = try reader.int32() }
            if flags2 & (1 << 10) != 0 { try skipStickerSet(reader: &reader) }
            if flags2 & (1 << 17) != 0 { try skipBotVerification(reader: &reader) }
            if flags2 & (1 << 18) != 0 { _ = try reader.int32() }
            if flags2 & (1 << 21) != 0 { _ = try reader.int64() }
            if flags2 & (1 << 22) != 0 { try skipProfileTab(reader: &reader) }
            return HSNativeParsedChatFull(
                peer: .channel(id),
                about: about,
                memberCount: memberCount,
                pendingRequests: pendingRequests,
                isMegagroup: true,
                isBroadcast: false
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatFull constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChatParticipantsCount(reader: inout HSTLReader) throws -> Int? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatParticipantsForbidden:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & 1 != 0 {
                try skipChatParticipant(reader: &reader)
                return 1
            }
            return nil
        case HSNativeMTProtoSchema.chatParticipants:
            _ = try reader.int64()
            let vectorConstructor = try reader.uint32()
            guard vectorConstructor == HSNativeMTProtoSchema.vector else {
                throw HSNativeMTProtoError.malformedPacket("expected ChatParticipant vector, got 0x\(String(vectorConstructor, radix: 16))")
            }
            let count = Int(try reader.int32())
            guard count >= 0 else {
                throw HSNativeMTProtoError.malformedPacket("negative ChatParticipant vector count")
            }
            for _ in 0..<count {
                try skipChatParticipant(reader: &reader)
            }
            _ = try reader.int32()
            return count
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatParticipants constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChatParticipantsPeer(reader: inout HSTLReader) throws -> HSNativePeer {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatParticipantsForbidden:
            let flags = try reader.uint32()
            let chatID = try reader.int64()
            if flags & 1 != 0 {
                try skipChatParticipant(reader: &reader)
            }
            return .chat(chatID)
        case HSNativeMTProtoSchema.chatParticipants:
            let chatID = try reader.int64()
            let vectorConstructor = try reader.uint32()
            guard vectorConstructor == HSNativeMTProtoSchema.vector else {
                throw HSNativeMTProtoError.malformedPacket("expected ChatParticipant vector, got 0x\(String(vectorConstructor, radix: 16))")
            }
            let count = Int(try reader.int32())
            guard count >= 0 else {
                throw HSNativeMTProtoError.malformedPacket("negative ChatParticipant vector count")
            }
            for _ in 0..<count {
                try skipChatParticipant(reader: &reader)
            }
            _ = try reader.int32()
            return .chat(chatID)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatParticipants constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDraftsResult(_ result: Data) throws -> HSNativeDraftsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updates, HSNativeMTProtoSchema.updatesCombined:
            let drafts = try parseVector(reader: &reader, elementName: "Update", parseDraftUpdate)
                .compactMap { draft -> HSDraft? in
                    guard let draft else {
                        return nil
                    }
                    guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return draft
                }
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            _ = try reader.int32()
            if constructor == HSNativeMTProtoSchema.updatesCombined {
                _ = try reader.int32()
            }
            _ = try reader.int32()
            return HSNativeDraftsPayload(drafts: drafts, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected Updates for drafts, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDraftUpdate(reader: inout HSTLReader) throws -> HSDraft? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.updateDraftMessage:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            if flags & (1 << 1) != 0 { _ = try parsePeer(reader: &reader) }
            return try parseDraftMessage(reader: &reader, dialogID: peer.dialogID)
        case HSNativeMTProtoSchema.updateDraftMessageLegacy:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            return try parseDraftMessage(reader: &reader, dialogID: peer.dialogID)
        case HSNativeMTProtoSchema.updateDraftMessageBare:
            let peer = try parsePeer(reader: &reader)
            return try parseDraftMessage(reader: &reader, dialogID: peer.dialogID)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported draft Update constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDraftMessage(reader: inout HSTLReader, dialogID: Int64) throws -> HSDraft? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.draftMessageEmpty:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int32() }
            return nil
        case HSNativeMTProtoSchema.draftMessage:
            let flags = try reader.uint32()
            let replyToMessageID = flags & (1 << 4) == 0 ? nil : try parseInputReplyToMessageID(reader: &reader)
            let text = try reader.string()
            if flags & (1 << 3) != 0 {
                try skipObjectVector(reader: &reader, name: "MessageEntity")
            }
            if flags & (1 << 5) != 0 {
                try skipUnsupportedObject(reader: &reader, name: "InputMedia")
            }
            let date = try reader.int32()
            if flags & (1 << 7) != 0 { _ = try reader.int64() }
            if flags & (1 << 8) != 0 { try skipSuggestedPost(reader: &reader) }
            return HSDraft(
                dialogID: dialogID,
                text: text,
                replyToMessageID: replyToMessageID,
                updatedAt: Date(timeIntervalSince1970: TimeInterval(date))
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DraftMessage constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseSendMessageResult(
        _ result: Data,
        dialogID: Int64,
        text: String,
        replyToMessageID: Int64?,
        sessionUserID: Int64?
    ) throws -> HSMessage {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updateShortSentMessage:
            let flags = try reader.uint32()
            let id = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            let date = try reader.int32()
            if flags & (1 << 9) != 0 {
                try skipMessageMedia(reader: &reader)
            }
            if flags & (1 << 7) != 0 {
                try skipObjectVector(reader: &reader, name: "MessageEntity")
            }
            if flags & (1 << 25) != 0 {
                _ = try reader.int32()
            }
            return HSMessage(
                id: Int64(id),
                dialogID: dialogID,
                authorID: sessionUserID ?? 0,
                authorName: "You",
                text: text,
                kind: flags & (1 << 9) == 0 ? nil : "media",
                sentAt: Date(timeIntervalSince1970: TimeInterval(date)),
                isOutgoing: true,
                replyToMessageID: replyToMessageID
            )
        case HSNativeMTProtoSchema.updateShort:
            let message = try parseUpdateMessage(reader: &reader)
            _ = try reader.int32()
            if let message,
               let mapped = hsMessage(from: message, fallbackDialogID: dialogID, users: [], chats: [], sessionUserID: sessionUserID) {
                return mapped
            }
        case HSNativeMTProtoSchema.updates, HSNativeMTProtoSchema.updatesCombined:
            let messages = try parseUpdatesBody(firstConstructor: constructor, reader: &reader)
            if let message = messages.first,
               let mapped = hsMessage(from: message, fallbackDialogID: dialogID, users: [], chats: [], sessionUserID: sessionUserID) {
                return mapped
            }
        case HSNativeMTProtoSchema.updateShortMessage:
            return try parseShortMessage(reader: &reader, dialogID: dialogID, text: text, sessionUserID: sessionUserID)
        case HSNativeMTProtoSchema.updateShortChatMessage:
            return try parseShortChatMessage(reader: &reader, dialogID: dialogID, text: text, sessionUserID: sessionUserID)
        case HSNativeMTProtoSchema.updatesTooLong:
            break
        default:
            throw HSNativeMTProtoError.malformedPacket("expected Updates, got 0x\(String(constructor, radix: 16))")
        }
        return HSMessage(
            id: Int64(Date().timeIntervalSince1970 * 1000),
            dialogID: dialogID,
            authorID: sessionUserID ?? 0,
            authorName: "You",
            text: text,
            kind: nil,
            sentAt: Date(),
            isOutgoing: true,
            replyToMessageID: replyToMessageID
        )
    }

    private static func parseForwardMessageResult(_ result: Data, toDialogID: Int64, sessionUserID: Int64?) throws -> HSMessage {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updates, HSNativeMTProtoSchema.updatesCombined:
            let messages = try parseUpdatesBody(firstConstructor: constructor, reader: &reader)
            if let message = messages.first,
               let mapped = hsMessage(from: message, fallbackDialogID: toDialogID, users: [], chats: [], sessionUserID: sessionUserID) {
                return mapped
            }
        case HSNativeMTProtoSchema.updateShort:
            let message = try parseUpdateMessage(reader: &reader)
            _ = try reader.int32()
            if let message,
               let mapped = hsMessage(from: message, fallbackDialogID: toDialogID, users: [], chats: [], sessionUserID: sessionUserID) {
                return mapped
            }
        case HSNativeMTProtoSchema.updatesTooLong:
            break
        default:
            throw HSNativeMTProtoError.malformedPacket("expected Updates, got 0x\(String(constructor, radix: 16))")
        }
        return HSMessage(
            id: Int64(Date().timeIntervalSince1970 * 1000),
            dialogID: toDialogID,
            authorID: sessionUserID ?? 0,
            authorName: "You",
            text: "Forwarded message",
            kind: nil,
            sentAt: Date(),
            isOutgoing: true,
            replyToMessageID: nil
        )
    }

    private static func parseBoolResult(_ result: Data) throws -> Bool {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.boolTrue:
            return true
        case HSNativeMTProtoSchema.boolFalse:
            return false
        default:
            throw HSNativeMTProtoError.malformedPacket("expected Bool, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseWebPagePreviewResult(_ result: Data) throws -> HSMessageMedia? {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesWebPagePreview:
            let media = try parseMessageMedia(reader: &reader)
            _ = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return media
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.WebPagePreview, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseUploadFileResult(_ result: Data) throws -> Data {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.uploadFile:
            try skipStorageFileType(reader: &reader)
            _ = try reader.int32()
            return try reader.bytes()
        case HSNativeMTProtoSchema.uploadFileCdnRedirect:
            throw HSNativeMTProtoError.malformedPacket("upload.fileCdnRedirect is not yet supported by the native media downloader")
        default:
            throw HSNativeMTProtoError.malformedPacket("expected upload.File, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePhotosPhotoResult(_ result: Data) throws {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.photosPhoto:
            try skipPhoto(reader: &reader)
            _ = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected photos.Photo, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipStorageFileType(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xaa963b05, 0x40bc6f52, 0x7efe0e, 0xcae1aadf, 0x0a4f63c0,
            0xae1e508d, 0x528a0677, 0x4b09ebbc, 0xb3cea0e4, 0x1081464c:
            return
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported storage.FileType constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAffectedMessagesResult(_ result: Data, dialogID: Int64, messageID: Int64?) throws -> HSMessageAction {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesAffectedMessages:
            let pts = try reader.int32()
            let ptsCount = try reader.int32()
            return HSMessageAction(
                ok: true,
                messageID: messageID,
                dialogID: dialogID,
                pts: Int(pts),
                ptsCount: Int(ptsCount)
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.AffectedMessages, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseContactsResult(_ result: Data) throws -> HSNativeContactsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.contactsContactsNotModified:
            return HSNativeContactsPayload(contactUserIDs: [], users: [])
        case HSNativeMTProtoSchema.contactsContacts:
            let contactIDs = try parseVector(reader: &reader, elementName: "Contact") { reader in
                try parseContactUserID(reader: &reader)
            }
            _ = try reader.int32()
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeContactsPayload(contactUserIDs: Set(contactIDs), users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected contacts.Contacts, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseBlockedContactsResult(_ result: Data) throws -> HSNativeBlockedContactsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.contactsBlocked, HSNativeMTProtoSchema.contactsBlockedSlice:
            if constructor == HSNativeMTProtoSchema.contactsBlockedSlice {
                _ = try reader.int32()
            }
            let blockedPeers = try parseVector(reader: &reader, elementName: "PeerBlocked", parsePeerBlocked)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let blockedUserIDs = Set(blockedPeers.compactMap(userID(from:)))
            return HSNativeBlockedContactsPayload(blockedUserIDs: blockedUserIDs, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected contacts.Blocked, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseContactsFoundResult(_ result: Data) throws -> HSNativeContactsFoundPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.contactsFound:
            let myResults = try parseVector(reader: &reader, elementName: "Peer", parsePeer)
            let results = try parseVector(reader: &reader, elementName: "Peer", parsePeer)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let myIDs = Set(myResults.compactMap(userID(from:)))
            let resultIDs = Set((myResults + results).compactMap(userID(from:)))
            return HSNativeContactsFoundPayload(myResultUserIDs: myIDs, resultUserIDs: resultIDs, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected contacts.Found, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseResolvedPeerResult(_ result: Data) throws -> HSNativeResolvedPeerPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.contactsResolvedPeer:
            let peer = try parsePeer(reader: &reader)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            return HSNativeResolvedPeerPayload(peer: peer, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected contacts.ResolvedPeer, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChannelParticipantsResult(_ result: Data, sessionUserID: Int64?) throws -> HSNativeChannelParticipantsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.channelsChannelParticipantsNotModified:
            return HSNativeChannelParticipantsPayload(members: [], chats: [], users: [])
        case HSNativeMTProtoSchema.channelsChannelParticipants:
            _ = try reader.int32()
            let participants = try parseVector(reader: &reader, elementName: "ChannelParticipant", parseChannelParticipant)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let members = participants.map { participant in
                let user = users.first { $0.id == participant.userID }
                return HSSupergroupMember(
                    id: participant.userID,
                    displayName: user?.title ?? "User \(participant.userID)",
                    username: user?.username,
                    role: participant.role,
                    rank: participant.rank,
                    joinedAt: participant.date.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    isSelf: participant.userID == sessionUserID
                )
            }
            return HSNativeChannelParticipantsPayload(members: members, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected channels.ChannelParticipants, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseInvitedUsersOrUpdatesSuccess(_ result: Data) throws {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesInvitedUsers:
            return
        default:
            try parseUpdatesSuccess(result)
        }
    }

    private static func parseAffectedHistoryResult(_ result: Data, dialogID: Int64) throws -> HSMessageAction {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesAffectedHistory:
            let pts = try reader.int32()
            let ptsCount = try reader.int32()
            _ = try reader.int32()
            return HSMessageAction(ok: true, messageID: nil, dialogID: dialogID, pts: Int(pts), ptsCount: Int(ptsCount))
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.AffectedHistory, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseExportedMessageLinkResult(_ result: Data) throws -> HSExportedMessageLink {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.exportedMessageLink:
            let link = try reader.string()
            let html = try reader.string()
            return HSExportedMessageLink(link: link, html: html)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected ExportedMessageLink, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseExportedInviteResult(_ result: Data, requestNeeded: Bool, fallbackTitle: String?) throws -> HSExportedInvite {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.chatInvitePublicJoinRequests:
            return HSExportedInvite(
                link: "",
                title: fallbackTitle,
                adminID: 0,
                date: Date(),
                expireDate: nil,
                usageLimit: nil,
                usage: nil,
                requested: nil,
                revoked: false,
                permanent: false,
                requestNeeded: true
            )
        case HSNativeMTProtoSchema.chatInviteExported:
            let flags = try reader.uint32()
            let link = try reader.string()
            let adminID = try reader.int64()
            let date = try reader.int32()
            if flags & (1 << 4) != 0 {
                _ = try reader.int32()
            }
            let expireDate = flags & (1 << 1) == 0 ? nil : Int(try reader.int32())
            let usageLimit = flags & (1 << 2) == 0 ? nil : Int(try reader.int32())
            let usage = flags & (1 << 3) == 0 ? nil : Int(try reader.int32())
            let requested = flags & (1 << 7) == 0 ? nil : Int(try reader.int32())
            let title = flags & (1 << 8) == 0 ? fallbackTitle : try reader.string()
            if flags & (1 << 10) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 9) != 0 {
                try skipUnsupportedObject(reader: &reader, name: "StarsSubscriptionPricing")
            }
            return HSExportedInvite(
                link: link,
                title: title,
                adminID: adminID,
                date: Date(timeIntervalSince1970: TimeInterval(date)),
                expireDate: expireDate,
                usageLimit: usageLimit,
                usage: usage,
                requested: requested,
                revoked: flags & 1 != 0,
                permanent: flags & (1 << 5) != 0,
                requestNeeded: requestNeeded || flags & (1 << 6) != 0
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected ExportedChatInvite, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAuthorizationsResult(_ result: Data) throws -> [HSDeviceSession] {
        try parseAuthorizationsPayloadResult(result).devices
    }

    private static func parseAuthorizationsPayloadResult(_ result: Data) throws -> HSNativeAuthorizationsPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.accountAuthorizations:
            _ = try reader.int32()
            let authorizations = try parseVector(reader: &reader, elementName: "Authorization", parseAuthorizationPayload)
            return HSNativeAuthorizationsPayload(
                devices: authorizations.map { $0.device },
                unconfirmedCount: authorizations.filter { $0.unconfirmed }.count
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected account.Authorizations, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePrivacyRulesSnapshotResult(_ result: Data) throws -> HSNativePrivacyRulesSnapshot {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.accountPrivacyRules:
            let rules = try parseVector(reader: &reader, elementName: "PrivacyRule", parsePrivacyRuleKind)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let selection = privacyRuleSelection(rules)
            let exceptions = privacyRuleExceptions(rules: rules, users: users, chats: chats)
            return HSNativePrivacyRulesSnapshot(
                value: privacyRuleSummary(selection: selection, exceptions: exceptions),
                selection: selection,
                exceptions: exceptions,
                users: users,
                chats: chats
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected account.PrivacyRules, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseNotifySettingsResult(_ result: Data) throws -> HSNotifyScopeSettings {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.peerNotifySettings:
            let flags = try reader.uint32()
            let showPreviews = flags & (1 << 0) == 0 ? true : try parseBool(reader: &reader)
            let silent = flags & (1 << 1) == 0 ? false : try parseBool(reader: &reader)
            let muteUntil = flags & (1 << 2) == 0 ? nil : Int(try reader.int32())
            if flags & (1 << 3) != 0 { try skipNotificationSound(reader: &reader) }
            if flags & (1 << 4) != 0 { try skipNotificationSound(reader: &reader) }
            if flags & (1 << 5) != 0 { try skipNotificationSound(reader: &reader) }
            if flags & (1 << 6) != 0 { try skipBool(reader: &reader) }
            if flags & (1 << 7) != 0 { try skipBool(reader: &reader) }
            if flags & (1 << 8) != 0 { try skipNotificationSound(reader: &reader) }
            if flags & (1 << 9) != 0 { try skipNotificationSound(reader: &reader) }
            if flags & (1 << 10) != 0 { try skipNotificationSound(reader: &reader) }
            let isEnabled = muteUntil.map { Int64($0) <= Int64(Date().timeIntervalSince1970) } ?? true
            return HSNotifyScopeSettings(
                enabled: isEnabled,
                showPreviews: showPreviews,
                silent: silent,
                muteUntil: muteUntil
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected PeerNotifySettings, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAllStickersResult(_ result: Data) throws -> [HSStickerSet] {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesAllStickersNotModified:
            return []
        case HSNativeMTProtoSchema.messagesAllStickers:
            _ = try reader.int64()
            return try parseVector(reader: &reader, elementName: "StickerSet") { reader in
                try parseStickerSet(reader: &reader, installed: true, featured: false, premium: false)
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.AllStickers, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseFeaturedStickersResult(_ result: Data) throws -> [HSStickerSet] {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesFeaturedStickersNotModified:
            _ = try reader.int32()
            return []
        case HSNativeMTProtoSchema.messagesFeaturedStickers:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int32()
            let premium = flags & 1 != 0
            let sets = try parseVector(reader: &reader, elementName: "StickerSetCovered") { reader in
                try parseStickerSetCovered(reader: &reader, premium: premium)
            }
            try skipInt64Vector(reader: &reader)
            return sets
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.FeaturedStickers, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAvailableReactionsResult(_ result: Data) throws -> [HSReaction] {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.messagesAvailableReactionsNotModified:
            return []
        case HSNativeMTProtoSchema.messagesAvailableReactions:
            _ = try reader.int32()
            return try parseVector(reader: &reader, elementName: "AvailableReaction", parseAvailableReaction)
                .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        default:
            throw HSNativeMTProtoError.malformedPacket("expected messages.AvailableReactions, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAdminLogResult(_ result: Data) throws -> HSNativeAdminLogPayload {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.channelsAdminLogResults:
            let drafts = try parseVector(reader: &reader, elementName: "ChannelAdminLogEvent", parseAdminLogEvent)
            let chats = try parseVector(reader: &reader, elementName: "Chat", parseChat)
            let users = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
            let events = drafts.map { draft in
                HSSupergroupAdminLogEvent(
                    id: draft.id,
                    date: Date(timeIntervalSince1970: TimeInterval(draft.date)),
                    actorID: draft.userID,
                    actorName: users.first(where: { $0.id == draft.userID })?.title ?? "User \(draft.userID)",
                    action: draft.action,
                    description: draft.description
                )
            }
            return HSNativeAdminLogPayload(events: events, chats: chats, users: users)
        default:
            throw HSNativeMTProtoError.malformedPacket("expected channels.AdminLogResults, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePrivacyRuleKind(reader: inout HSTLReader) throws -> HSNativePrivacyRuleKind {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.privacyValueAllowAll:
            return .allowAll
        case HSNativeMTProtoSchema.privacyValueAllowContacts:
            return .allowContacts
        case HSNativeMTProtoSchema.privacyValueDisallowAll:
            return .disallowAll
        case HSNativeMTProtoSchema.privacyValueAllowUsers:
            return .allowUsers(try parseInt64Vector(reader: &reader))
        case HSNativeMTProtoSchema.privacyValueDisallowUsers:
            return .disallowUsers(try parseInt64Vector(reader: &reader))
        case HSNativeMTProtoSchema.privacyValueAllowChatParticipants:
            return .allowChats(try parseInt64Vector(reader: &reader))
        case HSNativeMTProtoSchema.privacyValueDisallowChatParticipants:
            return .disallowChats(try parseInt64Vector(reader: &reader))
        case HSNativeMTProtoSchema.privacyValueAllowCloseFriends,
            HSNativeMTProtoSchema.privacyValueAllowPremium,
            HSNativeMTProtoSchema.privacyValueAllowBots,
            HSNativeMTProtoSchema.privacyValueDisallowBots,
            HSNativeMTProtoSchema.privacyValueDisallowContacts:
            return .custom
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PrivacyRule constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func privacyRuleSelection(_ rules: [HSNativePrivacyRuleKind]) -> HSPrivacyRuleValue {
        guard !rules.isEmpty else {
            return .serverDefault
        }
        var base: HSPrivacyRuleValue?
        var custom = false
        for rule in rules {
            switch rule {
            case .allowAll:
                base = .everyone
            case .allowContacts:
                base = .contacts
            case .disallowAll:
                base = .nobody
            case .allowUsers, .disallowUsers, .allowChats, .disallowChats, .custom:
                custom = true
            }
        }
        return base ?? (custom ? .custom : .serverDefault)
    }

    private static func privacyRuleExceptions(
        rules: [HSNativePrivacyRuleKind],
        users: [HSNativeParsedUser],
        chats: [HSNativeParsedChat]
    ) -> HSPrivacyRuleExceptions {
        var usersByID: [Int64: HSNativeParsedUser] = [:]
        for user in users {
            usersByID[user.id] = user
        }
        var chatsByID: [Int64: HSNativeParsedChat] = [:]
        for chat in chats {
            chatsByID[rawPeerID(from: chat.peer)] = chat
        }

        var allow: [HSPrivacyExceptionPeer] = []
        var disallow: [HSPrivacyExceptionPeer] = []

        for rule in rules {
            switch rule {
            case .allowUsers(let ids):
                allow.append(contentsOf: ids.map { privacyExceptionPeer(userID: $0, usersByID: usersByID) })
            case .disallowUsers(let ids):
                disallow.append(contentsOf: ids.map { privacyExceptionPeer(userID: $0, usersByID: usersByID) })
            case .allowChats(let ids):
                allow.append(contentsOf: ids.map { privacyExceptionPeer(chatID: $0, chatsByID: chatsByID) })
            case .disallowChats(let ids):
                disallow.append(contentsOf: ids.map { privacyExceptionPeer(chatID: $0, chatsByID: chatsByID) })
            case .allowAll, .allowContacts, .disallowAll, .custom:
                break
            }
        }

        return HSPrivacyRuleExceptions(
            allow: uniquePrivacyExceptionPeers(allow),
            disallow: uniquePrivacyExceptionPeers(disallow)
        )
    }

    private static func privacyRuleSummary(selection: HSPrivacyRuleValue, exceptions: HSPrivacyRuleExceptions) -> String {
        guard exceptions.totalCount > 0 else {
            return selection.label
        }
        return "\(selection.label)，\(exceptions.totalCount) 个例外"
    }

    private static func uniquePrivacyExceptionPeers(_ peers: [HSPrivacyExceptionPeer]) -> [HSPrivacyExceptionPeer] {
        var seen = Set<String>()
        var result: [HSPrivacyExceptionPeer] = []
        for peer in peers where !seen.contains(peer.id) {
            seen.insert(peer.id)
            result.append(peer)
        }
        return result
    }

    private static func privacyExceptionPeer(
        userID: Int64,
        usersByID: [Int64: HSNativeParsedUser]
    ) -> HSPrivacyExceptionPeer {
        if let user = usersByID[userID] {
            return HSPrivacyExceptionPeer(
                peerID: user.id,
                dialogID: user.id,
                title: user.title,
                subtitle: user.username.map { "@\($0)" },
                kind: .user
            )
        }
        return HSPrivacyExceptionPeer(peerID: userID, dialogID: userID, title: "User \(userID)", subtitle: nil, kind: .user)
    }

    private static func privacyExceptionPeer(
        chatID: Int64,
        chatsByID: [Int64: HSNativeParsedChat]
    ) -> HSPrivacyExceptionPeer {
        if let chat = chatsByID[chatID] {
            return HSPrivacyExceptionPeer(
                peerID: chatID,
                dialogID: chat.peer.dialogID,
                title: chat.title,
                subtitle: chat.about.isEmpty ? nil : chat.about,
                kind: chat.isBroadcast ? .channel : .group
            )
        }
        let dialogID = chatID > 0 ? -chatID : chatID
        return HSPrivacyExceptionPeer(peerID: chatID, dialogID: dialogID, title: "Chat \(chatID)", subtitle: nil, kind: .group)
    }

    private static func rawPeerID(from peer: HSNativePeer) -> Int64 {
        switch peer {
        case .user(let id), .chat(let id), .channel(let id):
            return id
        }
    }

    private static func privacySpec(id: String) throws -> HSNativePrivacySpec {
        guard let spec = hsNativePrivacySpecs.first(where: { $0.id == id }) else {
            throw HSNativeMTProtoError.malformedPacket("unsupported privacy key \(id)")
        }
        return spec
    }

    private static func privacyItem(spec: HSNativePrivacySpec, snapshot: HSNativePrivacyRulesSnapshot, status: String) -> HSSettingsItem {
        HSSettingsItem(
            id: spec.id,
            title: spec.title,
            subtitle: spec.subtitle,
            value: snapshot.value,
            status: status,
            selection: snapshot.selection.rawValue,
            exceptions: snapshot.exceptions
        )
    }

    private static func inputPrivacyRuleConstructor(for value: HSPrivacyRuleValue) -> UInt32 {
        switch value {
        case .everyone:
            return HSNativeMTProtoSchema.inputPrivacyValueAllowAll
        case .contacts:
            return HSNativeMTProtoSchema.inputPrivacyValueAllowContacts
        case .nobody:
            return HSNativeMTProtoSchema.inputPrivacyValueDisallowAll
        case .custom, .serverDefault:
            return HSNativeMTProtoSchema.inputPrivacyValueAllowContacts
        }
    }

    private func inputPrivacyRulePayloads(
        for value: HSPrivacyRuleValue,
        exceptions: HSPrivacyRuleExceptions
    ) throws -> [Data] {
        let allowUsers = try exceptions.allow
            .filter { $0.kind == .user }
            .map { try inputUserPayload(userID: $0.peerID) }
        let disallowUsers = try exceptions.disallow
            .filter { $0.kind == .user }
            .map { try inputUserPayload(userID: $0.peerID) }
        let allowChats = exceptions.allow
            .filter { $0.kind != .user }
            .map(\.peerID)
        let disallowChats = exceptions.disallow
            .filter { $0.kind != .user }
            .map(\.peerID)

        var rules: [Data] = []
        switch value {
        case .nobody:
            if !allowUsers.isEmpty {
                rules.append(Self.inputPrivacyUsersRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowUsers, users: allowUsers))
            }
            if !allowChats.isEmpty {
                rules.append(Self.inputPrivacyChatParticipantsRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowChatParticipants, chatIDs: allowChats))
            }
            rules.append(Self.inputPrivacySimpleRulePayload(HSNativeMTProtoSchema.inputPrivacyValueDisallowAll))
        case .contacts:
            if !allowUsers.isEmpty {
                rules.append(Self.inputPrivacyUsersRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowUsers, users: allowUsers))
            }
            if !allowChats.isEmpty {
                rules.append(Self.inputPrivacyChatParticipantsRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowChatParticipants, chatIDs: allowChats))
            }
            if !disallowUsers.isEmpty {
                rules.append(Self.inputPrivacyUsersRulePayload(HSNativeMTProtoSchema.inputPrivacyValueDisallowUsers, users: disallowUsers))
            }
            if !disallowChats.isEmpty {
                rules.append(Self.inputPrivacyChatParticipantsRulePayload(HSNativeMTProtoSchema.inputPrivacyValueDisallowChatParticipants, chatIDs: disallowChats))
            }
            rules.append(Self.inputPrivacySimpleRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowContacts))
        case .everyone:
            if !disallowUsers.isEmpty {
                rules.append(Self.inputPrivacyUsersRulePayload(HSNativeMTProtoSchema.inputPrivacyValueDisallowUsers, users: disallowUsers))
            }
            if !disallowChats.isEmpty {
                rules.append(Self.inputPrivacyChatParticipantsRulePayload(HSNativeMTProtoSchema.inputPrivacyValueDisallowChatParticipants, chatIDs: disallowChats))
            }
            rules.append(Self.inputPrivacySimpleRulePayload(HSNativeMTProtoSchema.inputPrivacyValueAllowAll))
        case .custom, .serverDefault:
            rules.append(Self.inputPrivacySimpleRulePayload(Self.inputPrivacyRuleConstructor(for: value)))
        }
        return rules
    }

    private static func inputPrivacySimpleRulePayload(_ constructor: UInt32) -> Data {
        var writer = HSTLWriter()
        writer.constructor(constructor)
        return writer.data
    }

    private static func inputPrivacyUsersRulePayload(_ constructor: UInt32, users: [Data]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(constructor)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(users.count))
        for user in users {
            writer.raw(user)
        }
        return writer.data
    }

    private static func inputPrivacyChatParticipantsRulePayload(_ constructor: UInt32, chatIDs: [Int64]) -> Data {
        var writer = HSTLWriter()
        writer.constructor(constructor)
        writer.constructor(HSNativeMTProtoSchema.vector)
        writer.int32(Int32(chatIDs.count))
        for chatID in chatIDs {
            writer.int64(chatID)
        }
        return writer.data
    }

    private static func trustItemsFromState(activeSessions: Int, unconfirmedSessions: Int, trustEvents: Int64) -> [HSTrustItem] {
        let deviceSeverity = unconfirmedSessions > 0 ? "attention" : "normal"
        let trustSeverity = trustEvents > 0 ? "attention" : "normal"
        return [
            HSTrustItem(
                id: "devices",
                title: "Devices",
                subtitle: deviceSubtitle(activeSessions: activeSessions, unconfirmedSessions: unconfirmedSessions),
                severity: deviceSeverity
            ),
            HSTrustItem(
                id: "reports",
                title: "Reports",
                subtitle: countSubtitle(trustEvents, singular: "trust event", plural: "trust events"),
                severity: trustSeverity
            ),
            HSTrustItem(
                id: "privacy",
                title: "Privacy",
                subtitle: "Privacy and account protection controls",
                severity: "normal"
            ),
            HSTrustItem(
                id: "support",
                title: "Support",
                subtitle: "Support contacts and request history",
                severity: "normal"
            )
        ]
    }

    private static func deviceSubtitle(activeSessions: Int, unconfirmedSessions: Int) -> String {
        if unconfirmedSessions > 0 {
            return countSubtitle(Int64(unconfirmedSessions), singular: "unconfirmed session", plural: "unconfirmed sessions")
        }
        return countSubtitle(Int64(activeSessions), singular: "active session", plural: "active sessions")
    }

    private static func countSubtitle(_ count: Int64, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }

    private static func workspaceSummary(
        session: HSUserSession,
        dialogs: [HSChat],
        contacts: [HSContact],
        activeSessions: Int,
        unconfirmedSessions: Int
    ) -> HSWorkspaceSummary {
        let unreadDialogs = dialogs.filter { $0.unreadCount > 0 || $0.isMarkedUnread }
        let contactRequests = contacts.filter { contact in
            let status = contact.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return status == "request" || status == "requested" || status == "pending"
        }
        let trustEvents = Int64(unconfirmedSessions)
        var actions: [HSWorkspaceAction] = []

        if !unreadDialogs.isEmpty {
            actions.append(HSWorkspaceAction(
                id: "unread_dialogs",
                kind: "dialog",
                title: "Unread Chats",
                subtitle: countSubtitle(Int64(unreadDialogs.count), singular: "chat needs attention", plural: "chats need attention"),
                badge: "\(unreadDialogs.count)",
                count: Int64(unreadDialogs.count),
                route: "/chats?filter=unread",
                groupID: nil,
                peerID: nil,
                peerNamespace: nil
            ))
        }

        if !contactRequests.isEmpty {
            actions.append(HSWorkspaceAction(
                id: "contact_requests",
                kind: "contact_request",
                title: "Contact Requests",
                subtitle: countSubtitle(Int64(contactRequests.count), singular: "request waiting", plural: "requests waiting"),
                badge: "\(contactRequests.count)",
                count: Int64(contactRequests.count),
                route: "/contacts/requests",
                groupID: nil,
                peerID: nil,
                peerNamespace: nil
            ))
        }

        if unconfirmedSessions > 0 {
            actions.append(HSWorkspaceAction(
                id: "unconfirmed_sessions",
                kind: "trust",
                title: "Review Devices",
                subtitle: countSubtitle(Int64(unconfirmedSessions), singular: "unconfirmed session", plural: "unconfirmed sessions"),
                badge: "\(unconfirmedSessions)",
                count: Int64(unconfirmedSessions),
                route: "/settings/devices",
                groupID: nil,
                peerID: nil,
                peerNamespace: nil
            ))
        }

        return HSWorkspaceSummary(
            userID: session.userID,
            source: "mtproto",
            generatedAt: Int64(Date().timeIntervalSince1970),
            counts: HSWorkspaceCounts(
                joinRequests: 0,
                ruleAcks: 0,
                trustEvents: trustEvents,
                contactRequests: Int64(contactRequests.count)
            ),
            actions: actions
        )
    }

    private static let serverEntitlements: [HSEntitlement] = [
        HSEntitlement(id: "advanced_identity", title: "Advanced Identity", subtitle: "Profile, username, and account-level controls", category: "profile", state: "included", included: true),
        HSEntitlement(id: "premium_assets", title: "Premium Assets", subtitle: "Premium reactions, stickers, emoji, and profile assets", category: "assets", state: "included", included: true),
        HSEntitlement(id: "enterprise_workspace", title: "Enterprise Workspace", subtitle: "Action inbox, contact requests, trust review, and support", category: "workspace", state: "included", included: true),
        HSEntitlement(id: "circle_governance", title: "Circle Governance", subtitle: "Roles, permissions, join requests, rules, and admin log", category: "circle", state: "included", included: true),
        HSEntitlement(id: "privacy_trust", title: "Privacy and Trust", subtitle: "Device sessions, privacy settings, reports, and safety review", category: "privacy", state: "included", included: true),
        HSEntitlement(id: "support_bridge", title: "Support Bridge", subtitle: "Admin contacts and support threads shared across clients", category: "support", state: "included", included: true)
    ]

    private static let serverAdminTools: [HSAdminTool] = [
        HSAdminTool(id: "auto_messages", title: "Auto Messages", subtitle: "Group recurring messages and sender controls", category: "automation", route: "/groups/auto-messages", status: "available", requiresOwner: false),
        HSAdminTool(id: "join_requests", title: "Join Requests", subtitle: "Circle member approvals and request queue", category: "circle", route: "/circles/join-requests", status: "migrating", requiresOwner: false),
        HSAdminTool(id: "member_permissions", title: "Member Permissions", subtitle: "Admin roles, restrictions, and hidden member controls", category: "moderation", route: "/circles/member-permissions", status: "migrating", requiresOwner: true),
        HSAdminTool(id: "admin_log", title: "Admin Log", subtitle: "Recent circle moderation and member events", category: "moderation", route: "/circles/admin-log", status: "migrating", requiresOwner: false),
        HSAdminTool(id: "premium_assets", title: "Premium Assets", subtitle: "Official premium catalog shared with Android and desktop", category: "assets", route: "/assets/premium", status: "available", requiresOwner: false),
        HSAdminTool(id: "support_threads", title: "Support Threads", subtitle: "User support mirror and admin contact workflow", category: "support", route: "/support/threads", status: "migrating", requiresOwner: false)
    ]

    private static func parseStickerSet(reader: inout HSTLReader, installed: Bool, featured: Bool, premium: Bool) throws -> HSStickerSet {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.stickerSet || constructor == HSNativeMTProtoSchema.stickerSetLegacy else {
            throw HSNativeMTProtoError.malformedPacket("unsupported StickerSet constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 { _ = try reader.int32() }
        let id = try reader.int64()
        _ = try reader.int64()
        let title = try reader.string()
        let shortName = try reader.string()
        if flags & (1 << 4) != 0 {
            try skipObjectVector(reader: &reader, name: "PhotoSize")
            _ = try reader.int32()
            _ = try reader.int32()
        }
        let thumbDocument: Int64? = constructor == HSNativeMTProtoSchema.stickerSet && flags & (1 << 8) != 0 ? try reader.int64() : nil
        let count = max(0, Int(try reader.int32()))
        _ = try reader.int32()
        let premiumFlags = flags & (1 << 7) != 0 || flags & (1 << 9) != 0 || flags & (1 << 10) != 0
        return HSStickerSet(
            id: id,
            title: title,
            shortName: shortName,
            count: count,
            installed: installed || flags & 1 != 0,
            featured: featured,
            official: flags & (1 << 2) != 0,
            premium: premium || premiumFlags,
            animated: flags & (1 << 5) != 0,
            videos: flags & (1 << 6) != 0,
            thumbDocument: thumbDocument
        )
    }

    private static func parseStickerSetCovered(reader: inout HSTLReader, premium: Bool) throws -> HSStickerSet {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.stickerSetCovered:
            let set = try parseStickerSet(reader: &reader, installed: false, featured: true, premium: premium)
            let cover = try parseDocumentID(reader: &reader)
            return set.withThumbDocument(cover)
        case HSNativeMTProtoSchema.stickerSetFullCovered:
            let set = try parseStickerSet(reader: &reader, installed: false, featured: true, premium: premium)
            try skipStickerPackVector(reader: &reader)
            try skipStickerKeywordVector(reader: &reader)
            let cover = try parseDocumentIDVectorFirst(reader: &reader)
            return set.withThumbDocument(cover)
        case HSNativeMTProtoSchema.stickerSetMultiCovered:
            let set = try parseStickerSet(reader: &reader, installed: false, featured: true, premium: premium)
            let cover = try parseDocumentIDVectorFirst(reader: &reader)
            return set.withThumbDocument(cover)
        case HSNativeMTProtoSchema.stickerSetNoCovered:
            return try parseStickerSet(reader: &reader, installed: false, featured: true, premium: premium)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported StickerSetCovered constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAvailableReaction(reader: inout HSTLReader) throws -> HSReaction {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.availableReaction else {
            throw HSNativeMTProtoError.malformedPacket("unsupported AvailableReaction constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let reaction = try reader.string()
        let title = try reader.string()
        for _ in 0..<5 {
            _ = try parseDocumentID(reader: &reader)
        }
        if flags & (1 << 1) != 0 {
            _ = try parseDocumentID(reader: &reader)
            _ = try parseDocumentID(reader: &reader)
        }
        return HSReaction(
            id: reaction,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? reaction : title,
            premium: flags & (1 << 2) != 0,
            inactive: flags & 1 != 0
        )
    }

    private static func parseUpdatesSuccess(_ result: Data) throws {
        var reader = HSTLReader(data: try unpackGzipPackedIfNeeded(result))
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.rpcError:
            throw try parseRPCError(reader: &reader)
        case HSNativeMTProtoSchema.updatesTooLong,
            HSNativeMTProtoSchema.updateShortSentMessage,
            HSNativeMTProtoSchema.updateShort,
            HSNativeMTProtoSchema.updateShortMessage,
            HSNativeMTProtoSchema.updateShortChatMessage,
            HSNativeMTProtoSchema.updates,
            HSNativeMTProtoSchema.updatesCombined:
            return
        default:
            throw HSNativeMTProtoError.malformedPacket("expected Updates, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseContactUserID(reader: inout HSTLReader) throws -> Int64 {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.contact else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Contact constructor 0x\(String(constructor, radix: 16))")
        }
        let userID = try reader.int64()
        try skipBool(reader: &reader)
        return userID
    }

    private static func parsePeerBlocked(reader: inout HSTLReader) throws -> HSNativePeer {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.peerBlocked else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PeerBlocked constructor 0x\(String(constructor, radix: 16))")
        }
        let peer = try parsePeer(reader: &reader)
        _ = try reader.int32()
        return peer
    }

    private static func parseChannelParticipant(reader: inout HSTLReader) throws -> HSNativeParsedChannelParticipant {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.channelParticipant:
            let flags = try reader.uint32()
            let userID = try reader.int64()
            let date = try reader.int32()
            if flags & 1 != 0 {
                _ = try reader.int32()
            }
            let rank = flags & (1 << 2) == 0 ? nil : try reader.string()
            return HSNativeParsedChannelParticipant(userID: userID, role: "member", rank: rank, date: date)
        case HSNativeMTProtoSchema.channelParticipantSelf:
            let flags = try reader.uint32()
            let userID = try reader.int64()
            _ = try reader.int64()
            let date = try reader.int32()
            if flags & (1 << 1) != 0 {
                _ = try reader.int32()
            }
            let rank = flags & (1 << 2) == 0 ? nil : try reader.string()
            return HSNativeParsedChannelParticipant(userID: userID, role: "member", rank: rank, date: date)
        case HSNativeMTProtoSchema.channelParticipantCreator:
            let flags = try reader.uint32()
            let userID = try reader.int64()
            try skipChatAdminRights(reader: &reader)
            let rank = flags & 1 == 0 ? nil : try reader.string()
            return HSNativeParsedChannelParticipant(userID: userID, role: "creator", rank: rank, date: nil)
        case HSNativeMTProtoSchema.channelParticipantAdmin:
            let flags = try reader.uint32()
            let userID = try reader.int64()
            if flags & (1 << 1) != 0 {
                _ = try reader.int64()
            }
            _ = try reader.int64()
            let date = try reader.int32()
            try skipChatAdminRights(reader: &reader)
            let rank = flags & (1 << 2) == 0 ? nil : try reader.string()
            return HSNativeParsedChannelParticipant(userID: userID, role: "admin", rank: rank, date: date)
        case HSNativeMTProtoSchema.channelParticipantBanned:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            let userID = userID(from: peer) ?? peer.dialogID
            _ = try reader.int64()
            let date = try reader.int32()
            try skipChatBannedRights(reader: &reader)
            let rank = flags & (1 << 2) == 0 ? nil : try reader.string()
            return HSNativeParsedChannelParticipant(userID: userID, role: flags & 1 == 0 ? "banned" : "left", rank: rank, date: date)
        case HSNativeMTProtoSchema.channelParticipantLeft:
            let peer = try parsePeer(reader: &reader)
            let userID = userID(from: peer) ?? peer.dialogID
            return HSNativeParsedChannelParticipant(userID: userID, role: "left", rank: nil, date: nil)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChannelParticipant constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseAuthorizationPayload(reader: inout HSTLReader) throws -> (device: HSDeviceSession, unconfirmed: Bool) {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.authorization else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Authorization constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let hash = try reader.int64()
        let deviceModel = try reader.string()
        let platform = try reader.string()
        let systemVersion = try reader.string()
        _ = try reader.int32()
        let appName = try reader.string()
        let appVersion = try reader.string()
        _ = try reader.int32()
        let dateActive = try reader.int32()
        let ip = try reader.string()
        let country = try reader.string()
        let region = try reader.string()
        let device = HSDeviceSession(
            id: hash,
            current: flags & 1 != 0,
            deviceModel: deviceModel,
            platform: platform,
            systemVersion: systemVersion,
            appName: appName,
            appVersion: appVersion,
            ip: ip,
            country: country,
            region: region,
            dateActive: Date(timeIntervalSince1970: TimeInterval(dateActive))
        )
        return (device, flags & (1 << 5) != 0)
    }

    private static func parseAuthorizationDevice(reader: inout HSTLReader) throws -> HSDeviceSession {
        try parseAuthorizationPayload(reader: &reader).device
    }

    private static func parseAdminLogEvent(reader: inout HSTLReader) throws -> (id: Int64, date: Int32, userID: Int64, action: String, description: String) {
        let constructor = try reader.uint32()
        guard constructor == 0x1fad68cd else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ChannelAdminLogEvent constructor 0x\(String(constructor, radix: 16))")
        }
        let id = try reader.int64()
        let date = try reader.int32()
        let userID = try reader.int64()
        let summary = try parseAdminLogAction(reader: &reader)
        return (id, date, userID, summary.action, summary.description)
    }

    private static func parseAdminLogAction(reader: inout HSTLReader) throws -> (action: String, description: String) {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xe6dfb825:
            let previous = try reader.string()
            let new = try reader.string()
            return ("Change title", "Changed title from \(previous) to \(new)")
        case 0x55188a2e:
            let previous = try reader.string()
            let new = try reader.string()
            return ("Change description", "Changed description from \(previous) to \(new)")
        case 0x6a4afc38:
            let previous = try reader.string()
            let new = try reader.string()
            return ("Change username", "Changed username from \(previous) to \(new)")
        case 0xf04fb3a9:
            let previous = try parseStringVector(reader: &reader)
            let new = try parseStringVector(reader: &reader)
            return ("Change usernames", "Changed usernames from \(previous.joined(separator: ", ")) to \(new.joined(separator: ", "))")
        case 0x434bd2af:
            try skipPhoto(reader: &reader)
            try skipPhoto(reader: &reader)
            return ("Change photo", "Updated group photo")
        case 0xe31c34d8:
            _ = try parseChannelParticipant(reader: &reader)
            return ("Invite member", "Invited a member")
        case 0x183040d3:
            return ("Member joined", "A member joined")
        case 0xf89777f2:
            return ("Member left", "A member left")
        case 0x5806b4ec:
            let userID = try reader.int64()
            let previous = try reader.string()
            let new = try reader.string()
            return ("Edit rank", "Changed rank for User \(userID) from \(previous) to \(new)")
        case 0xd5676710:
            _ = try parseChannelParticipant(reader: &reader)
            _ = try parseChannelParticipant(reader: &reader)
            return ("Edit admin", "Updated admin permissions")
        case 0xe6d83d7e:
            _ = try parseChannelParticipant(reader: &reader)
            _ = try parseChannelParticipant(reader: &reader)
            return ("Edit restrictions", "Updated member restrictions")
        case 0x53909779:
            let previous = try reader.int32()
            let new = try reader.int32()
            return ("Slow mode", "Changed slow mode from \(previous)s to \(new)s")
        case 0x5f5c95f1:
            let enabled = try parseBool(reader: &reader)
            return ("History visibility", "Set previous history visibility to \(enabled ? "enabled" : "disabled")")
        case 0xe9e82c18:
            _ = try parseMessage(reader: &reader)
            return ("Pinned message", "Updated pinned message")
        case 0x42e047bb:
            _ = try parseMessage(reader: &reader)
            return ("Delete message", "Deleted a message")
        case 0x709b2405:
            _ = try parseMessage(reader: &reader)
            _ = try parseMessage(reader: &reader)
            return ("Edit message", "Edited a message")
        case 0x278f2868:
            _ = try parseMessage(reader: &reader)
            return ("Send message", "Sent a message")
        case 0x1b7907ae:
            _ = try parseBool(reader: &reader)
            return ("Invite links", "Updated invite link permissions")
        case 0x2df5fc0a:
            try skipChatBannedRights(reader: &reader)
            try skipChatBannedRights(reader: &reader)
            return ("Default restrictions", "Updated default member restrictions")
        case 0x26ae0971:
            _ = try parseBool(reader: &reader)
            return ("Signatures", "Updated message signature settings")
        case 0xb1c3caa7:
            try skipInputStickerSet(reader: &reader)
            try skipInputStickerSet(reader: &reader)
            return ("Sticker set", "Updated linked sticker set")
        case 0x8f079643:
            _ = try parseMessage(reader: &reader)
            return ("Stop poll", "Stopped a poll")
        case 0x50c7ac8:
            _ = try reader.int64()
            _ = try reader.int64()
            return ("Linked chat", "Updated linked chat")
        case 0xe6b76ae:
            try skipChannelLocation(reader: &reader)
            try skipChannelLocation(reader: &reader)
            return ("Location", "Updated group location")
        case 0x23209745:
            try skipInputGroupCall(reader: &reader)
            return ("Start group call", "Started a group call")
        case 0xdb9f9140:
            try skipInputGroupCall(reader: &reader)
            return ("End group call", "Ended a group call")
        case 0xf92424d2:
            try skipGroupCallParticipant(reader: &reader)
            return ("Mute participant", "Muted a call participant")
        case 0xe64429c0:
            try skipGroupCallParticipant(reader: &reader)
            return ("Unmute participant", "Unmuted a call participant")
        case 0x56d6a247:
            _ = try parseBool(reader: &reader)
            return ("Group call setting", "Updated group call settings")
        case 0xfe9fc158:
            let flags = try reader.uint32()
            _ = flags
            try skipExportedChatInvite(reader: &reader)
            return ("Join by invite", "A member joined through an invite")
        case 0x5a50fca4:
            try skipExportedChatInvite(reader: &reader)
            return ("Delete invite", "Deleted an invite link")
        case 0x410a134e:
            try skipExportedChatInvite(reader: &reader)
            return ("Revoke invite", "Revoked an invite link")
        case 0xe90ebb59:
            try skipExportedChatInvite(reader: &reader)
            try skipExportedChatInvite(reader: &reader)
            return ("Edit invite", "Edited an invite link")
        case 0x3e7f6847:
            try skipGroupCallParticipant(reader: &reader)
            return ("Participant volume", "Updated participant volume")
        case 0x6e941a38:
            _ = try reader.int32()
            _ = try reader.int32()
            return ("History TTL", "Updated message auto-delete timer")
        case 0xafb6144a:
            try skipExportedChatInvite(reader: &reader)
            _ = try reader.int64()
            return ("Join request", "Approved a join request")
        case 0xcb2ac766:
            _ = try parseBool(reader: &reader)
            return ("Forwarding", "Updated forwarding restrictions")
        case 0xbe4e0ef8, 0x9cf7f76a:
            try skipChatReactions(reader: &reader)
            try skipChatReactions(reader: &reader)
            return ("Available reactions", "Updated available reactions")
        case 0x2cc6383:
            _ = try parseBool(reader: &reader)
            return ("Topics", "Updated forum topic mode")
        case 0x58707d28:
            try skipForumTopic(reader: &reader)
            return ("Create topic", "Created a topic")
        case 0xf06fe208:
            try skipForumTopic(reader: &reader)
            try skipForumTopic(reader: &reader)
            return ("Edit topic", "Edited a topic")
        case 0xae168909:
            try skipForumTopic(reader: &reader)
            return ("Delete topic", "Deleted a topic")
        case 0x5d8d353b:
            let flags = try reader.uint32()
            if flags & 1 != 0 { try skipForumTopic(reader: &reader) }
            if flags & (1 << 1) != 0 { try skipForumTopic(reader: &reader) }
            return ("Pin topic", "Updated pinned topic")
        case 0x64f36dfc:
            _ = try parseBool(reader: &reader)
            return ("Anti-spam", "Updated anti-spam settings")
        case 0x5796e780, 0x5e477b25:
            try skipPeerColor(reader: &reader)
            try skipPeerColor(reader: &reader)
            return ("Profile color", "Updated profile color")
        case 0x31bb5d52:
            try skipWallPaper(reader: &reader)
            try skipWallPaper(reader: &reader)
            return ("Wallpaper", "Updated wallpaper")
        case 0x3ea9feb1:
            try skipEmojiStatus(reader: &reader)
            try skipEmojiStatus(reader: &reader)
            return ("Emoji status", "Updated emoji status")
        case 0x46d840ab:
            try skipInputStickerSet(reader: &reader)
            try skipInputStickerSet(reader: &reader)
            return ("Emoji sticker set", "Updated emoji sticker set")
        case 0x60a79c79:
            _ = try parseBool(reader: &reader)
            return ("Signature profiles", "Updated signature profile settings")
        case 0x64642db3:
            _ = try parseChannelParticipant(reader: &reader)
            _ = try parseChannelParticipant(reader: &reader)
            return ("Subscription", "Updated member subscription")
        case 0xc517f77e:
            _ = try parseBool(reader: &reader)
            return ("Auto translation", "Updated auto-translation settings")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChannelAdminLogEventAction constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseVector<T>(
        reader: inout HSTLReader,
        elementName: String,
        _ parse: (inout HSTLReader) throws -> T
    ) throws -> [T] {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected \(elementName) vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative \(elementName) vector count")
        }
        var values: [T] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try parse(&reader))
        }
        return values
    }

    private static func skipEmptyVector(reader: inout HSTLReader, name: String) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected \(name) vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count == 0 else {
            throw HSNativeMTProtoError.malformedPacket("native parser does not yet support non-empty \(name) vectors")
        }
    }

    private static func skipEncryptedMessageVector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected EncryptedMessage vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count == 0 else {
            throw HSNativeMTProtoError.malformedPacket("secret-chat EncryptedMessage difference is not supported in this native rebuild pass")
        }
    }

    private static func parseDialogFilter(reader: inout HSTLReader, sessionUserID: Int64) throws -> HSChatListFilter {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.dialogFilterDefault:
            return HSChatListFilter(
                id: 0,
                title: "全部",
                emoticon: nil,
                color: nil,
                isDefault: true,
                isShared: false,
                hasSharedLinks: false,
                categories: .all,
                excludeMuted: false,
                excludeRead: false,
                excludeArchived: false,
                includePeers: [],
                pinnedPeers: [],
                excludePeers: [],
                titleAnimationsEnabled: true
            )
        case HSNativeMTProtoSchema.dialogFilter, HSNativeMTProtoSchema.dialogFilterChatlist:
            let flags = try reader.uint32()
            let id = Int(try reader.int32())
            let title = try parseTextWithEntitiesText(reader: &reader)
            let emoticon = flags & (1 << 25) != 0 ? try reader.string() : nil
            let color = flags & (1 << 27) != 0 ? Int(try reader.int32()) : nil
            let pinnedPeers = try parseInputPeerVector(reader: &reader, sessionUserID: sessionUserID)
            let includePeers = try parseInputPeerVector(reader: &reader, sessionUserID: sessionUserID)
            let excludePeers: [HSChatListFilterPeer]
            if constructor == HSNativeMTProtoSchema.dialogFilter {
                excludePeers = try parseInputPeerVector(reader: &reader, sessionUserID: sessionUserID)
            } else {
                excludePeers = []
            }
            return HSChatListFilter(
                id: id,
                title: title,
                emoticon: emoticon,
                color: color,
                isDefault: false,
                isShared: constructor == HSNativeMTProtoSchema.dialogFilterChatlist,
                hasSharedLinks: flags & (1 << 26) != 0,
                categories: HSChatListFilterPeerCategories(rawValue: Int32(bitPattern: flags & 0x1f)),
                excludeMuted: flags & (1 << 11) != 0,
                excludeRead: flags & (1 << 12) != 0,
                excludeArchived: flags & (1 << 13) != 0,
                includePeers: pinnedPeers + includePeers,
                pinnedPeers: pinnedPeers,
                excludePeers: excludePeers,
                titleAnimationsEnabled: flags & (1 << 28) == 0
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DialogFilter constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseTextWithEntitiesText(reader: inout HSTLReader) throws -> String {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.textWithEntities else {
            throw HSNativeMTProtoError.malformedPacket("unsupported TextWithEntities constructor 0x\(String(constructor, radix: 16))")
        }
        let text = try reader.string()
        try skipObjectVector(reader: &reader, name: "MessageEntity")
        return text
    }

    private static func parseInputPeerVector(reader: inout HSTLReader, sessionUserID: Int64) throws -> [HSChatListFilterPeer] {
        try parseVector(reader: &reader, elementName: "InputPeer") { reader in
            try parseInputPeer(reader: &reader, sessionUserID: sessionUserID)
        }
        .compactMap { $0 }
    }

    private static func parseInputPeer(reader: inout HSTLReader, sessionUserID: Int64) throws -> HSChatListFilterPeer? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.inputPeerEmpty:
            return nil
        case HSNativeMTProtoSchema.inputPeerSelf:
            return HSChatListFilterPeer(kind: .user, peerID: sessionUserID, dialogID: sessionUserID, accessHash: nil)
        case HSNativeMTProtoSchema.inputPeerChat:
            let chatID = try reader.int64()
            return HSChatListFilterPeer(kind: .chat, peerID: chatID, dialogID: -chatID, accessHash: nil)
        case HSNativeMTProtoSchema.inputPeerUser:
            let userID = try reader.int64()
            let accessHash = try reader.int64()
            return HSChatListFilterPeer(kind: .user, peerID: userID, dialogID: userID, accessHash: accessHash)
        case HSNativeMTProtoSchema.inputPeerChannel:
            let channelID = try reader.int64()
            let accessHash = try reader.int64()
            return HSChatListFilterPeer(
                kind: .channel,
                peerID: channelID,
                dialogID: HSNativePeer.channelDialogID(channelID),
                accessHash: accessHash
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported InputPeer constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDialog(reader: inout HSTLReader) throws -> HSNativeParsedDialog {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.dialog else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Dialog constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let peer = try parsePeer(reader: &reader)
        let topMessage = try reader.int32()
        let readInboxMaxID = try reader.int32()
        let readOutboxMaxID = try reader.int32()
        let unreadCount = try reader.int32()
        _ = try reader.int32()
        _ = try reader.int32()
        let isMuted = try skipPeerNotifySettings(reader: &reader)
        if flags & (1 << 0) != 0 {
            _ = try reader.int32()
        }
        if flags & (1 << 1) != 0 {
            try skipDraftMessage(reader: &reader)
        }
        let folderID = flags & (1 << 4) != 0 ? Int(try reader.int32()) : nil
        if flags & (1 << 5) != 0 {
            _ = try reader.int32()
        }
        return HSNativeParsedDialog(
            peer: peer,
            topMessageID: topMessage,
            readInboxMaxID: readInboxMaxID,
            readOutboxMaxID: readOutboxMaxID,
            unreadCount: unreadCount,
            isMarkedUnread: flags & (1 << 3) != 0,
            isPinned: flags & (1 << 2) != 0,
            folderID: folderID,
            isMuted: isMuted
        )
    }

    private static func parsePeer(reader: inout HSTLReader) throws -> HSNativePeer {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.peerUser:
            return .user(try reader.int64())
        case HSNativeMTProtoSchema.peerChat:
            return .chat(try reader.int64())
        case HSNativeMTProtoSchema.peerChannel:
            return .channel(try reader.int64())
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Peer constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDialogPeer(reader: inout HSTLReader) throws -> HSNativePeer? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.dialogPeer:
            return try parsePeer(reader: &reader)
        case HSNativeMTProtoSchema.dialogPeerFolder:
            _ = try reader.int32()
            return nil
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DialogPeer constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDialogPeerVector(reader: inout HSTLReader) throws -> [HSNativePeer] {
        try parseVector(reader: &reader, elementName: "DialogPeer", parseDialogPeer).compactMap { $0 }
    }

    private static func parseFolderPeer(reader: inout HSTLReader) throws -> HSNativePeer {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.folderPeer else {
            throw HSNativeMTProtoError.malformedPacket("unsupported FolderPeer constructor 0x\(String(constructor, radix: 16))")
        }
        let peer = try parsePeer(reader: &reader)
        _ = try reader.int32()
        return peer
    }

    private static func parseMessage(reader: inout HSTLReader) throws -> HSNativeParsedMessage {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.messageEmpty:
            let flags = try reader.uint32()
            let id = try reader.int32()
            let peer = flags & 1 == 0 ? nil : try parsePeer(reader: &reader)
            return HSNativeParsedMessage(id: id, peer: peer, fromPeer: nil, date: nil, text: "", kind: "service", media: nil, isOutgoing: false, replyToMessageID: nil, reactions: [], counters: HSMessageCounters(), editDate: nil, authorSignature: nil)
        case HSNativeMTProtoSchema.message:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let id = try reader.int32()
            let fromPeer = flags & (1 << 8) == 0 ? nil : try parsePeer(reader: &reader)
            if flags & (1 << 29) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 12) != 0 {
                _ = try reader.string()
            }
            let peer = try parsePeer(reader: &reader)
            if flags & (1 << 28) != 0 {
                _ = try parsePeer(reader: &reader)
            }
            if flags & (1 << 2) != 0 {
                try skipMessageFwdHeader(reader: &reader)
            }
            if flags & (1 << 11) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 0) != 0 {
                _ = try reader.int64()
            }
            let replyTo = flags & (1 << 3) == 0 ? nil : try parseMessageReplyHeader(reader: &reader)
            let date = try reader.int32()
            let text = try reader.string()
            let hasMedia = flags & (1 << 9) != 0
            let media = hasMedia ? try parseMessageMedia(reader: &reader) : nil
            if flags & (1 << 6) != 0 {
                try skipReplyMarkup(reader: &reader)
            }
            if flags & (1 << 7) != 0 {
                try skipObjectVector(reader: &reader, name: "MessageEntity")
            }
            var counters = HSMessageCounters()
            if flags & (1 << 10) != 0 {
                let viewCount = Int(try reader.int32())
                let forwardCount = Int(try reader.int32())
                counters = HSMessageCounters(viewCount: viewCount, forwardCount: forwardCount, replyCount: counters.replyCount)
            }
            if flags & (1 << 23) != 0 {
                counters = HSMessageCounters(
                    viewCount: counters.viewCount,
                    forwardCount: counters.forwardCount,
                    replyCount: try parseMessageRepliesCount(reader: &reader)
                )
            }
            let editDate = flags & (1 << 15) == 0 ? nil : try reader.int32()
            let authorSignature = flags & (1 << 16) == 0 ? nil : try reader.string()
            if flags & (1 << 17) != 0 {
                _ = try reader.int64()
            }
            let reactions = flags & (1 << 20) == 0 ? [] : try parseMessageReactions(reader: &reader)
            if flags & (1 << 22) != 0 {
                try skipRestrictionReasons(reader: &reader)
            }
            if flags & (1 << 25) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 30) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 2) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 3) != 0 {
                try skipFactCheck(reader: &reader)
            }
            if flags2 & (1 << 5) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 6) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 7) != 0 {
                try skipSuggestedPost(reader: &reader)
            }
            if flags2 & (1 << 10) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 11) != 0 {
                _ = try reader.string()
            }
            return HSNativeParsedMessage(
                id: id,
                peer: peer,
                fromPeer: fromPeer,
                date: date,
                text: text,
                kind: hasMedia ? "media" : nil,
                media: media,
                isOutgoing: flags & (1 << 1) != 0,
                replyToMessageID: replyTo,
                reactions: reactions,
                counters: counters,
                editDate: editDate,
                authorSignature: authorSignature
            )
        case HSNativeMTProtoSchema.messageService:
            let flags = try reader.uint32()
            let id = try reader.int32()
            let fromPeer = flags & (1 << 8) == 0 ? nil : try parsePeer(reader: &reader)
            let peer = try parsePeer(reader: &reader)
            if flags & (1 << 28) != 0 {
                _ = try parsePeer(reader: &reader)
            }
            let replyTo = flags & (1 << 3) == 0 ? nil : try parseMessageReplyHeader(reader: &reader)
            let date = try reader.int32()
            try skipMessageAction(reader: &reader)
            let reactions = flags & (1 << 20) == 0 ? [] : try parseMessageReactions(reader: &reader)
            if flags & (1 << 25) != 0 {
                _ = try reader.int32()
            }
            return HSNativeParsedMessage(
                id: id,
                peer: peer,
                fromPeer: fromPeer,
                date: date,
                text: "Service update",
                kind: "service",
                media: nil,
                isOutgoing: flags & (1 << 1) != 0,
                replyToMessageID: replyTo,
                reactions: reactions,
                counters: HSMessageCounters(),
                editDate: nil,
                authorSignature: nil
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Message constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseChat(reader: inout HSTLReader) throws -> HSNativeParsedChat {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatEmpty:
            let id = try reader.int64()
            return HSNativeParsedChat(peer: .chat(id), accessHash: nil, title: "Chat \(id)", isGroupLike: true, about: "", memberCount: 0, role: "member", isMegagroup: false, isBroadcast: false)
        case HSNativeMTProtoSchema.chatForbidden:
            let id = try reader.int64()
            let title = try reader.string()
            return HSNativeParsedChat(peer: .chat(id), accessHash: nil, title: title, isGroupLike: true, about: "", memberCount: 0, role: "member", isMegagroup: false, isBroadcast: false)
        case HSNativeMTProtoSchema.chat:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let title = try reader.string()
            try skipChatPhoto(reader: &reader)
            let participantsCount = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & (1 << 6) != 0 {
                try skipInputChannel(reader: &reader)
            }
            if flags & (1 << 14) != 0 {
                try skipChatAdminRights(reader: &reader)
            }
            if flags & (1 << 18) != 0 {
                try skipChatBannedRights(reader: &reader)
            }
            return HSNativeParsedChat(
                peer: .chat(id),
                accessHash: nil,
                title: title,
                isGroupLike: true,
                about: "",
                memberCount: Int(participantsCount),
                role: flags & 1 != 0 ? "creator" : "member",
                isMegagroup: false,
                isBroadcast: false
            )
        case HSNativeMTProtoSchema.channelForbidden:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let accessHash = try reader.int64()
            let title = try reader.string()
            if flags & (1 << 16) != 0 {
                _ = try reader.int32()
            }
            let broadcast = flags & (1 << 5) != 0
            let megagroup = flags & (1 << 8) != 0 || !broadcast
            return HSNativeParsedChat(peer: .channel(id), accessHash: accessHash, title: title, isGroupLike: true, about: "", memberCount: 0, role: "member", isMegagroup: megagroup, isBroadcast: broadcast)
        case HSNativeMTProtoSchema.channel:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let id = try reader.int64()
            let accessHash = flags & (1 << 13) == 0 ? nil : try reader.int64()
            let title = try reader.string()
            let username = try readOptionalString(reader: &reader, flags: flags, bit: 6)
            try skipChatPhoto(reader: &reader)
            _ = try reader.int32()
            if flags & (1 << 9) != 0 {
                try skipRestrictionReasons(reader: &reader)
            }
            if flags & (1 << 14) != 0 {
                try skipChatAdminRights(reader: &reader)
            }
            if flags & (1 << 15) != 0 {
                try skipChatBannedRights(reader: &reader)
            }
            if flags & (1 << 18) != 0 {
                try skipChatBannedRights(reader: &reader)
            }
            var participantsCount = 0
            if flags & (1 << 17) != 0 {
                participantsCount = Int(try reader.int32())
            }
            if flags2 & (1 << 0) != 0 {
                try skipUsernames(reader: &reader)
            }
            if flags2 & (1 << 4) != 0 {
                try skipRecentStory(reader: &reader)
            }
            if flags2 & (1 << 7) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 8) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 9) != 0 {
                try skipEmojiStatus(reader: &reader)
            }
            if flags2 & (1 << 10) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 11) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 13) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 14) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 18) != 0 {
                _ = try reader.int64()
            }
            let broadcast = flags & (1 << 5) != 0
            let megagroup = flags & (1 << 8) != 0 || !broadcast
            return HSNativeParsedChat(
                peer: .channel(id),
                accessHash: accessHash,
                title: title,
                isGroupLike: true,
                about: username.map { "@\($0)" } ?? "",
                memberCount: participantsCount,
                role: flags & 1 != 0 ? "creator" : "member",
                isMegagroup: megagroup,
                isBroadcast: broadcast
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Chat constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseUserSummary(reader: inout HSTLReader) throws -> HSNativeParsedUser {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.userEmpty:
            let id = try reader.int64()
            return HSNativeParsedUser(id: id, accessHash: nil, title: "User \(id)", username: nil, flags: 0)
        case HSNativeMTProtoSchema.user:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let id = try reader.int64()
            let accessHash = flags & (1 << 0) == 0 ? nil : try reader.int64()
            let firstName = try readOptionalString(reader: &reader, flags: flags, bit: 1)
            let lastName = try readOptionalString(reader: &reader, flags: flags, bit: 2)
            let username = try readOptionalString(reader: &reader, flags: flags, bit: 3)
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 4)
            if flags & (1 << 5) != 0 {
                try skipUserProfilePhoto(reader: &reader)
            }
            if flags & (1 << 6) != 0 {
                try skipUserStatus(reader: &reader)
            }
            if flags & (1 << 14) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 18) != 0 {
                try skipRestrictionReasons(reader: &reader)
            }
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 19)
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 22)
            if flags & (1 << 30) != 0 {
                try skipEmojiStatus(reader: &reader)
            }
            if flags2 & (1 << 0) != 0 {
                try skipUsernames(reader: &reader)
            }
            if flags2 & (1 << 5) != 0 {
                try skipRecentStory(reader: &reader)
            }
            if flags2 & (1 << 8) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 9) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 12) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 14) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 15) != 0 {
                _ = try reader.int64()
            }
            return HSNativeParsedUser(
                id: id,
                accessHash: accessHash,
                title: displayName(firstName: firstName, lastName: lastName, username: username, fallback: "User \(id)"),
                username: username,
                flags: flags
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported User constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseUpdatesBody(firstConstructor constructor: UInt32, reader: inout HSTLReader) throws -> [HSNativeParsedMessage] {
        let updates = try parseVector(reader: &reader, elementName: "Update", parseUpdateMessage)
        _ = try parseVector(reader: &reader, elementName: "User", parseUserSummary)
        _ = try parseVector(reader: &reader, elementName: "Chat", parseChat)
        _ = try reader.int32()
        if constructor == HSNativeMTProtoSchema.updatesCombined {
            _ = try reader.int32()
        }
        _ = try reader.int32()
        return updates.compactMap { $0 }
    }

    private static func parseUpdateMessage(reader: inout HSTLReader) throws -> HSNativeParsedMessage? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.updateNewMessage,
            HSNativeMTProtoSchema.updateNewChannelMessage,
            HSNativeMTProtoSchema.updateEditMessage,
            HSNativeMTProtoSchema.updateEditChannelMessage:
            let message = try parseMessage(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return message
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Update constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDifferenceUpdate(reader: inout HSTLReader) throws -> HSNativeParsedDifferenceUpdate {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.updateNewMessage,
            HSNativeMTProtoSchema.updateNewChannelMessage,
            HSNativeMTProtoSchema.updateEditMessage,
            HSNativeMTProtoSchema.updateEditChannelMessage:
            let message = try parseMessage(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(
                message: message,
                affectedDialogIDs: message.peer.map { [$0.dialogID] } ?? [],
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateMessageID:
            _ = try reader.int32()
            _ = try reader.int64()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateDeleteMessages:
            try skipInt32Vector(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateUserTyping:
            let flags = try reader.uint32()
            let userID = try reader.int64()
            if flags & 1 != 0 { _ = try reader.int32() }
            let action = try parseSendMessageAction(reader: &reader)
            let activity = inputActivity(dialogID: userID, userID: userID, action: action)
            return HSNativeParsedDifferenceUpdate(
                message: nil,
                affectedDialogIDs: [],
                inputActivity: activity,
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateChatUserTyping:
            let chatID = try reader.int64()
            let fromPeer = try parsePeer(reader: &reader)
            let action = try parseSendMessageAction(reader: &reader)
            let dialogID = HSNativePeer.chat(chatID).dialogID
            let activity = inputActivity(dialogID: dialogID, userID: rawPeerID(from: fromPeer), action: action)
            return HSNativeParsedDifferenceUpdate(
                message: nil,
                affectedDialogIDs: [],
                inputActivity: activity,
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateChannelUserTyping:
            let flags = try reader.uint32()
            let channelID = try reader.int64()
            if flags & 1 != 0 { _ = try reader.int32() }
            let fromPeer = try parsePeer(reader: &reader)
            let action = try parseSendMessageAction(reader: &reader)
            let dialogID = HSNativePeer.channel(channelID).dialogID
            let activity = inputActivity(dialogID: dialogID, userID: rawPeerID(from: fromPeer), action: action)
            return HSNativeParsedDifferenceUpdate(
                message: nil,
                affectedDialogIDs: [],
                inputActivity: activity,
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateChatParticipants:
            let peer = try parseChatParticipantsPeer(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateUserStatus:
            _ = try reader.int64()
            try skipUserStatus(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateUserName:
            _ = try reader.int64()
            _ = try reader.string()
            _ = try reader.string()
            try skipUsernames(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateUserPhone:
            _ = try reader.int64()
            _ = try reader.string()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateUserEmojiStatus:
            _ = try reader.int64()
            try skipEmojiStatus(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateUser:
            _ = try reader.int64()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateNewAuthorization:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & 1 != 0 {
                _ = try reader.int32()
                _ = try reader.string()
                _ = try reader.string()
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateChatParticipantAdd:
            let chatID = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.chat(chatID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChatParticipantDelete:
            let chatID = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.chat(chatID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChatParticipantAdmin:
            let chatID = try reader.int64()
            _ = try reader.int64()
            try skipBool(reader: &reader)
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.chat(chatID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateNotifySettings:
            let peer = try parseNotifyPeer(reader: &reader)
            try skipPeerNotifySettings(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peer.map { [$0.dialogID] } ?? [], affectsAllDialogs: peer == nil)
        case HSNativeMTProtoSchema.updatePrivacy:
            try skipPrivacyKey(reader: &reader)
            _ = try parseVector(reader: &reader, elementName: "PrivacyRule", parsePrivacyRuleKind)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateReadHistoryInbox,
            HSNativeMTProtoSchema.updateReadHistoryInboxLegacy:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int32() }
            let peer = try parsePeer(reader: &reader)
            if constructor == HSNativeMTProtoSchema.updateReadHistoryInbox && flags & (1 << 1) != 0 {
                _ = try reader.int32()
            }
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateReadHistoryOutbox:
            let peer = try parsePeer(reader: &reader)
            let maxID = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(
                message: nil,
                affectedDialogIDs: [peer.dialogID],
                readOutboxMaxIDsByDialogID: [peer.dialogID: Int64(maxID)],
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateReadMessagesContents:
            let flags = try reader.uint32()
            try skipInt32Vector(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.int32() }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateReadChannelInbox:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int32() }
            let channelID = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateReadChannelOutbox:
            let channelID = try reader.int64()
            let maxID = try reader.int32()
            let dialogID = HSNativePeer.channel(channelID).dialogID
            return HSNativeParsedDifferenceUpdate(
                message: nil,
                affectedDialogIDs: [dialogID],
                readOutboxMaxIDsByDialogID: [dialogID: Int64(maxID)],
                affectsAllDialogs: false
            )
        case HSNativeMTProtoSchema.updateDeleteChannelMessages:
            let channelID = try reader.int64()
            try skipInt32Vector(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChannelMessageViews,
            HSNativeMTProtoSchema.updateChannelMessageForwards:
            let channelID = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChannelReadMessagesContents,
            HSNativeMTProtoSchema.updateChannelReadMessagesContentsLegacy:
            let flags = try reader.uint32()
            let channelID = try reader.int64()
            if flags & 1 != 0 { _ = try reader.int32() }
            if constructor == HSNativeMTProtoSchema.updateChannelReadMessagesContents && flags & (1 << 1) != 0 {
                _ = try parsePeer(reader: &reader)
            }
            try skipInt32Vector(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateDraftMessage:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            if flags & (1 << 1) != 0 { _ = try parsePeer(reader: &reader) }
            try skipDraftMessage(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateDraftMessageLegacy:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            try skipDraftMessage(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateDraftMessageBare:
            let peer = try parsePeer(reader: &reader)
            try skipDraftMessage(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateDialogPinned:
            let flags = try reader.uint32()
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
            let peer = try parseDialogPeer(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peer.map { [$0.dialogID] } ?? [], affectsAllDialogs: peer == nil)
        case HSNativeMTProtoSchema.updatePinnedDialogs:
            let flags = try reader.uint32()
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
            if flags & 1 != 0 {
                let peers = try parseDialogPeerVector(reader: &reader)
                return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peers.map(\.dialogID), affectsAllDialogs: peers.isEmpty)
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateDialogUnreadMark,
            HSNativeMTProtoSchema.updateDialogUnreadMarkLegacy:
            let flags = try reader.uint32()
            let peer = try parseDialogPeer(reader: &reader)
            if constructor == HSNativeMTProtoSchema.updateDialogUnreadMark && flags & (1 << 1) != 0 {
                _ = try parsePeer(reader: &reader)
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peer.map { [$0.dialogID] } ?? [], affectsAllDialogs: peer == nil)
        case HSNativeMTProtoSchema.updateFolderPeers:
            let peers = try parseVector(reader: &reader, elementName: "FolderPeer", parseFolderPeer)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peers.map(\.dialogID), affectsAllDialogs: peers.isEmpty)
        case HSNativeMTProtoSchema.updatePeerSettings:
            let peer = try parsePeer(reader: &reader)
            try skipPeerSettings(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChatDefaultBannedRights:
            let peer = try parsePeer(reader: &reader)
            try skipChatBannedRights(reader: &reader)
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateGeoLiveViewed:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePeerBlocked:
            _ = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePeerHistoryTTL:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChatParticipant:
            let flags = try reader.uint32()
            let chatID = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int64()
            _ = try reader.int64()
            if flags & 1 != 0 { try skipChatParticipant(reader: &reader) }
            if flags & (1 << 1) != 0 { try skipChatParticipant(reader: &reader) }
            if flags & (1 << 2) != 0 { try skipExportedChatInvite(reader: &reader) }
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.chat(chatID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChannelParticipant:
            let flags = try reader.uint32()
            let channelID = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int64()
            _ = try reader.int64()
            if flags & 1 != 0 { _ = try parseChannelParticipant(reader: &reader) }
            if flags & (1 << 1) != 0 { _ = try parseChannelParticipant(reader: &reader) }
            if flags & (1 << 2) != 0 { try skipExportedChatInvite(reader: &reader) }
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateBotCommands:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int64()
            try skipObjectVector(reader: &reader, name: "BotCommand")
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePendingJoinRequests:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            try skipInt64Vector(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateTranscribedAudio:
            _ = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int64()
            _ = try reader.string()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateMessageExtendedMedia:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "MessageExtendedMedia")
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePeerWallpaper:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            if flags & 1 != 0 { try skipWallPaper(reader: &reader) }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePinnedMessages:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            try skipInt32Vector(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            _ = flags
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePinnedChannelMessages:
            let flags = try reader.uint32()
            let channelID = try reader.int64()
            try skipInt32Vector(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            _ = flags
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateMessageReactions:
            let flags = try reader.uint32()
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.int32() }
            let savedPeer = flags & (1 << 1) == 0 ? nil : try parsePeer(reader: &reader)
            try skipMessageReactions(reader: &reader)
            var affectedDialogIDs = [peer.dialogID]
            if let savedPeer {
                affectedDialogIDs.append(savedPeer.dialogID)
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: affectedDialogIDs, affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateBotMessageReaction:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try parsePeer(reader: &reader)
            try skipReactionVector(reader: &reader)
            try skipReactionVector(reader: &reader)
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateBotMessageReactions:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "ReactionCount")
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [peer.dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateRecentReactions,
            HSNativeMTProtoSchema.updateSavedReactionTags,
            HSNativeMTProtoSchema.updateReadFeaturedStickers,
            HSNativeMTProtoSchema.updateRecentStickers,
            HSNativeMTProtoSchema.updateConfig,
            HSNativeMTProtoSchema.updateContactsReset,
            HSNativeMTProtoSchema.updateReadFeaturedEmojiStickers,
            HSNativeMTProtoSchema.updateRecentEmojiStatuses,
            HSNativeMTProtoSchema.updateAttachMenuBots,
            HSNativeMTProtoSchema.updateSavedRingtones,
            HSNativeMTProtoSchema.updateAutoSaveSettings,
            HSNativeMTProtoSchema.updateSavedGifs,
            HSNativeMTProtoSchema.updateFavedStickers:
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateSavedDialogPinned:
            _ = try reader.uint32()
            let peer = try parseDialogPeer(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peer.map { [$0.dialogID] } ?? [], affectsAllDialogs: peer == nil)
        case HSNativeMTProtoSchema.updatePinnedSavedDialogs:
            let flags = try reader.uint32()
            if flags & 1 != 0 {
                let peers = try parseDialogPeerVector(reader: &reader)
                return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: peers.map(\.dialogID), affectsAllDialogs: peers.isEmpty)
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateDialogFilter:
            let flags = try reader.uint32()
            _ = try reader.int32()
            if flags & 1 != 0 {
                _ = try parseDialogFilter(reader: &reader, sessionUserID: 0)
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateDialogFilterOrder:
            try skipInt32Vector(reader: &reader)
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateDialogFilters:
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateChannel,
            HSNativeMTProtoSchema.updateChannelAvailableMessages:
            let channelID = try reader.int64()
            if constructor == HSNativeMTProtoSchema.updateChannelAvailableMessages {
                _ = try reader.int32()
            }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChannelTooLong:
            let flags = try reader.uint32()
            let channelID = try reader.int64()
            if flags & 1 != 0 { _ = try reader.int32() }
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateChat:
            let chatID = try reader.int64()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.chat(chatID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updateWebPage:
            try skipWebPage(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        case HSNativeMTProtoSchema.updateChannelWebPage:
            let channelID = try reader.int64()
            try skipWebPage(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [HSNativePeer.channel(channelID).dialogID], affectsAllDialogs: false)
        case HSNativeMTProtoSchema.updatePtsChanged:
            return HSNativeParsedDifferenceUpdate(message: nil, affectedDialogIDs: [], affectsAllDialogs: true)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Update constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseShortMessage(
        reader: inout HSTLReader,
        dialogID: Int64,
        text fallbackText: String,
        sessionUserID: Int64?
    ) throws -> HSMessage {
        let flags = try reader.uint32()
        let id = try reader.int32()
        let userID = try reader.int64()
        let text = try reader.string()
        _ = try reader.int32()
        _ = try reader.int32()
        let date = try reader.int32()
        if flags & (1 << 2) != 0 {
            try skipMessageFwdHeader(reader: &reader)
        }
        if flags & (1 << 11) != 0 {
            _ = try reader.int64()
        }
        let replyTo = flags & (1 << 3) == 0 ? nil : try parseMessageReplyHeader(reader: &reader)
        if flags & (1 << 7) != 0 {
            try skipObjectVector(reader: &reader, name: "MessageEntity")
        }
        if flags & (1 << 25) != 0 {
            _ = try reader.int32()
        }
        return HSMessage(
            id: Int64(id),
            dialogID: dialogID,
            authorID: flags & (1 << 1) == 0 ? userID : (sessionUserID ?? 0),
            authorName: flags & (1 << 1) == 0 ? "User \(userID)" : "You",
            text: text.isEmpty ? fallbackText : text,
            kind: nil,
            sentAt: Date(timeIntervalSince1970: TimeInterval(date)),
            isOutgoing: flags & (1 << 1) != 0,
            replyToMessageID: replyTo
        )
    }

    private static func parseShortChatMessage(
        reader: inout HSTLReader,
        dialogID: Int64,
        text fallbackText: String,
        sessionUserID: Int64?
    ) throws -> HSMessage {
        let flags = try reader.uint32()
        let id = try reader.int32()
        let fromID = try reader.int64()
        let chatID = try reader.int64()
        let text = try reader.string()
        _ = try reader.int32()
        _ = try reader.int32()
        let date = try reader.int32()
        if flags & (1 << 2) != 0 {
            try skipMessageFwdHeader(reader: &reader)
        }
        if flags & (1 << 11) != 0 {
            _ = try reader.int64()
        }
        let replyTo = flags & (1 << 3) == 0 ? nil : try parseMessageReplyHeader(reader: &reader)
        if flags & (1 << 7) != 0 {
            try skipObjectVector(reader: &reader, name: "MessageEntity")
        }
        if flags & (1 << 25) != 0 {
            _ = try reader.int32()
        }
        return HSMessage(
            id: Int64(id),
            dialogID: dialogID == 0 ? -chatID : dialogID,
            authorID: fromID,
            authorName: fromID == sessionUserID ? "You" : "User \(fromID)",
            text: text.isEmpty ? fallbackText : text,
            kind: nil,
            sentAt: Date(timeIntervalSince1970: TimeInterval(date)),
            isOutgoing: flags & (1 << 1) != 0,
            replyToMessageID: replyTo
        )
    }

    private func peerTitle(_ peer: HSNativePeer, users: [HSNativeParsedUser], chats: [HSNativeParsedChat]) -> String {
        switch peer {
        case .user(let id):
            if let user = users.first(where: { $0.id == id }) {
                return user.title
            }
        case .chat(let id), .channel(let id):
            if let chat = chats.first(where: {
                switch $0.peer {
                case .chat(let chatID), .channel(let chatID):
                    return chatID == id
                case .user:
                    return false
                }
            }) {
                return chat.title
            }
        }
        return peerCacheQueue.sync {
            cachedPeersByDialogID[peer.dialogID]?.title ?? Self.fallbackPeerTitle(peer)
        }
    }

    private static func fallbackPeerTitle(_ peer: HSNativePeer) -> String {
        switch peer {
        case .user(let id):
            return "User \(id)"
        case .chat(let id):
            return "Group \(id)"
        case .channel(let id):
            return "Channel \(id)"
        }
    }

    private static func peerKind(from peer: HSNativePeer) -> HSChatPeerKind {
        switch peer {
        case .user:
            return .user
        case .chat:
            return .chat
        case .channel:
            return .channel
        }
    }

    private static func parsedUser(for peer: HSNativePeer, users: [HSNativeParsedUser]) -> HSNativeParsedUser? {
        guard case let .user(id) = peer else {
            return nil
        }
        return users.first { $0.id == id }
    }

    private static func parsedChat(for peer: HSNativePeer, chats: [HSNativeParsedChat]) -> HSNativeParsedChat? {
        switch peer {
        case .chat(let id), .channel(let id):
            return chats.first {
                switch $0.peer {
                case .chat(let chatID), .channel(let chatID):
                    return chatID == id
                case .user:
                    return false
                }
            }
        case .user:
            return nil
        }
    }

    private static func messageListText(_ message: HSNativeParsedMessage) -> String {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return message.text
        }
        if let media = message.media {
            return messageListText(for: media)
        }
        return message.kind == "media" ? "Media" : "Message"
    }

    private static func messageListText(for media: HSMessageMedia) -> String {
        switch media.kind {
        case .photo:
            return "Photo"
        case .video:
            return media.fileName ?? "Video"
        case .gif:
            return media.fileName ?? "GIF"
        case .audio:
            return media.fileName ?? "Audio"
        case .voice:
            return "Voice Message"
        case .sticker:
            return media.fileName ?? "Sticker"
        case .webpage:
            return media.webPage?.title
                ?? media.webPage?.siteName
                ?? media.webPage?.displayURL
                ?? media.webPage?.url
                ?? "Link Preview"
        case .file:
            return media.fileName ?? "File"
        case .unknown:
            return media.fileName ?? "Media"
        }
    }

    private static func hsMessage(
        from message: HSNativeParsedMessage,
        fallbackDialogID: Int64,
        users: [HSNativeParsedUser],
        chats: [HSNativeParsedChat],
        sessionUserID: Int64?
    ) -> HSMessage? {
        let peer = message.peer
        let fromPeer = message.fromPeer ?? peer
        let authorID = fromPeer?.dialogID ?? 0
        return HSMessage(
            id: Int64(message.id),
            dialogID: peer?.dialogID ?? fallbackDialogID,
            authorID: authorID,
            authorName: authorName(fromPeer, users: users, chats: chats, sessionUserID: sessionUserID),
            text: message.text,
            kind: message.kind,
            sentAt: Date(timeIntervalSince1970: TimeInterval(message.date ?? Int32(Date().timeIntervalSince1970))),
            isOutgoing: message.isOutgoing,
            replyToMessageID: message.replyToMessageID,
            media: message.media,
            reactions: message.reactions,
            counters: message.counters,
            editDate: message.editDate.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            authorSignature: cleanMessageAuthorSignature(message.authorSignature)
        )
    }

    private static func cleanMessageAuthorSignature(_ value: String?) -> String? {
        guard let signature = value?.trimmingCharacters(in: .whitespacesAndNewlines), !signature.isEmpty else {
            return nil
        }
        return signature
    }

    private static func authorName(
        _ peer: HSNativePeer?,
        users: [HSNativeParsedUser],
        chats: [HSNativeParsedChat],
        sessionUserID: Int64?
    ) -> String {
        guard let peer else {
            return ""
        }
        if case .user(let id) = peer, id == sessionUserID {
            return "You"
        }
        switch peer {
        case .user(let id):
            return users.first(where: { $0.id == id })?.title ?? "User \(id)"
        case .chat(let id):
            return chats.first(where: { $0.peer == .chat(id) })?.title ?? "Group \(id)"
        case .channel(let id):
            return chats.first(where: { $0.peer == .channel(id) })?.title ?? "Channel \(id)"
        }
    }

    private static func supergroup(from chat: HSNativeParsedChat) -> HSSupergroup? {
        let channelID: Int64
        switch chat.peer {
        case .user:
            return nil
        case .chat(let id), .channel(let id):
            channelID = id
        }
        return HSSupergroup(
            id: chat.peer.dialogID,
            channelID: channelID,
            title: chat.title,
            about: chat.about,
            memberCount: chat.memberCount,
            pendingRequests: 0,
            role: chat.role,
            isMegagroup: chat.isMegagroup,
            isBroadcast: chat.isBroadcast
        )
    }

    private static func hsContact(from user: HSNativeParsedUser, forcedStatus: String?) -> HSContact {
        HSContact(
            id: user.id,
            displayName: user.title,
            username: user.username,
            status: forcedStatus ?? contactStatus(flags: user.flags)
        )
    }

    private static func contactStatus(flags: UInt32) -> String {
        if flags & (1 << 11) != 0 {
            return "mutual"
        }
        if flags & (1 << 10) != 0 {
            return "contact"
        }
        return "global"
    }

    private enum HSNativeResolvedContactKind {
        case username
        case phone
    }

    private static func normalizedContactIdentifier(_ identifier: String) -> (kind: HSNativeResolvedContactKind, value: String) {
        var value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: value), let host = url.host?.lowercased(), host == "t.me" || host == "telegram.me" || host == "hsgram.cloud" {
            value = url.path.split(separator: "/").first.map(String.init) ?? ""
        } else if let url = URL(string: "https://\(value)"),
                  let host = url.host?.lowercased(),
                  host == "t.me" || host == "telegram.me" || host == "hsgram.cloud" {
            value = url.path.split(separator: "/").first.map(String.init) ?? ""
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
        let phoneCharacters = CharacterSet(charactersIn: "+0123456789 -()")
        if !value.isEmpty,
           value.rangeOfCharacter(from: phoneCharacters.inverted) == nil,
           value.filter(\.isNumber).count >= 5 {
            return (.phone, value.filter { $0.isNumber })
        }
        return (.username, value.trimmingCharacters(in: CharacterSet(charactersIn: "@")))
    }

    private static func userID(from peer: HSNativePeer) -> Int64? {
        if case .user(let id) = peer {
            return id
        }
        return nil
    }

    private static func displayName(firstName: String?, lastName: String?, username: String?, fallback: String) -> String {
        let joined = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !joined.isEmpty {
            return joined
        }
        if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "@\(username)"
        }
        return fallback
    }

    private static func safeFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "file" : trimmed
        let disallowed = CharacterSet(charactersIn: "/\\:")
        return fallback.components(separatedBy: disallowed).joined(separator: "_")
    }

    private static func md5Hex(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func parsePasswordKdfAlgo(reader: inout HSTLReader, allowUnknown: Bool) throws -> HSNativePasswordKDF.Algorithm? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.passwordKdfAlgoUnknown:
            if allowUnknown {
                return nil
            }
            throw HSAPIError.server(code: "PASSWORD_KDF_ALGO_UNKNOWN", message: "服务端返回了暂不支持的密码 KDF。")
        case HSNativeMTProtoSchema.passwordKdfAlgoModPow:
            let salt1 = try reader.bytes()
            let salt2 = try reader.bytes()
            let g = try reader.int32()
            let p = try reader.bytes()
            return HSNativePasswordKDF.Algorithm(salt1: salt1, salt2: salt2, g: g, p: p)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PasswordKdfAlgo constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipSecurePasswordKdfAlgo(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.securePasswordKdfAlgoUnknown:
            return
        case HSNativeMTProtoSchema.securePasswordKdfAlgoPBKDF2,
            HSNativeMTProtoSchema.securePasswordKdfAlgoSHA512:
            _ = try reader.bytes()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported SecurePasswordKdfAlgo constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseRPCError(reader: inout HSTLReader) throws -> HSAPIError {
        _ = try reader.int32()
        let message = try reader.string()
        return HSAPIError.server(code: message, message: message)
    }

    private static func unpackGzipPackedIfNeeded(_ data: Data) throws -> Data {
        var reader = HSTLReader(data: data)
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.gzipPacked else {
            return data
        }
        let packedData = try reader.bytes()
        return try gzipDecompress(packedData)
    }

    private static func gzipDecompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else {
            return Data()
        }

        var stream = z_stream()
        let initStatus = inflateInit2_(
            &stream,
            16 + MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initStatus == Z_OK else {
            throw HSNativeMTProtoError.malformedPacket("gzip inflate init failed: \(initStatus)")
        }
        defer {
            inflateEnd(&stream)
        }

        var output = Data()
        let status = data.withUnsafeBytes { rawBuffer -> Int32 in
            guard let input = rawBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return Z_STREAM_END
            }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: input)
            stream.avail_in = uInt(data.count)

            var status: Int32 = Z_OK
            while status == Z_OK {
                var chunk = [UInt8](repeating: 0, count: 32 * 1024)
                chunk.withUnsafeMutableBufferPointer { outputBuffer in
                    stream.next_out = outputBuffer.baseAddress
                    stream.avail_out = uInt(outputBuffer.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                    let produced = outputBuffer.count - Int(stream.avail_out)
                    if produced > 0, let baseAddress = outputBuffer.baseAddress {
                        output.append(baseAddress, count: produced)
                    }
                }
            }
            return status
        }
        guard status == Z_STREAM_END else {
            throw HSNativeMTProtoError.malformedPacket("gzip inflate failed: \(status)")
        }
        return output
    }

    private static func parseUserSession(reader: inout HSTLReader, email: String, fallbackName: String) throws -> HSUserSession {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.userEmpty:
            _ = try reader.int64()
            throw HSAPIError.server(code: "USER_EMPTY", message: "登录成功但服务端没有返回完整用户资料。")
        case HSNativeMTProtoSchema.user:
            let flags = try reader.uint32()
            let flags2 = try reader.uint32()
            let userID = try reader.int64()
            if flags & (1 << 0) != 0 {
                _ = try reader.int64()
            }
            let firstName = try readOptionalString(reader: &reader, flags: flags, bit: 1)
            let lastName = try readOptionalString(reader: &reader, flags: flags, bit: 2)
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 3)
            let phone = try readOptionalString(reader: &reader, flags: flags, bit: 4)
            if flags & (1 << 5) != 0 {
                try skipUserProfilePhoto(reader: &reader)
            }
            if flags & (1 << 6) != 0 {
                try skipUserStatus(reader: &reader)
            }
            if flags & (1 << 14) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 18) != 0 {
                try skipRestrictionReasons(reader: &reader)
            }
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 19)
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 22)
            if flags & (1 << 30) != 0 {
                try skipEmojiStatus(reader: &reader)
            }
            if flags2 & (1 << 0) != 0 {
                try skipUsernames(reader: &reader)
            }
            if flags2 & (1 << 5) != 0 {
                try skipUnsupportedObject(reader: &reader, name: "RecentStory")
            }
            if flags2 & (1 << 8) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 9) != 0 {
                try skipPeerColor(reader: &reader)
            }
            if flags2 & (1 << 12) != 0 {
                _ = try reader.int32()
            }
            if flags2 & (1 << 14) != 0 {
                _ = try reader.int64()
            }
            if flags2 & (1 << 15) != 0 {
                _ = try reader.int64()
            }

            let displayName = [firstName, lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return HSUserSession(
                token: "mtproto:\(userID)",
                userID: userID,
                displayName: displayName.isEmpty ? fallbackDisplayName(email: email, fallbackName: fallbackName) : displayName,
                email: phone ?? email
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("expected User, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func readOptionalString(reader: inout HSTLReader, flags: UInt32, bit: Int) throws -> String? {
        guard flags & (UInt32(1) << UInt32(bit)) != 0 else {
            return nil
        }
        return try reader.string()
    }

    @discardableResult
    private static func skipPeerNotifySettings(reader: inout HSTLReader) throws -> Bool {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.peerNotifySettings else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PeerNotifySettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 0) != 0 { try skipBool(reader: &reader) }
        if flags & (1 << 1) != 0 { try skipBool(reader: &reader) }
        let muteUntil = flags & (1 << 2) != 0 ? Int(try reader.int32()) : nil
        if flags & (1 << 3) != 0 { try skipNotificationSound(reader: &reader) }
        if flags & (1 << 4) != 0 { try skipNotificationSound(reader: &reader) }
        if flags & (1 << 5) != 0 { try skipNotificationSound(reader: &reader) }
        if flags & (1 << 6) != 0 { try skipBool(reader: &reader) }
        if flags & (1 << 7) != 0 { try skipBool(reader: &reader) }
        if flags & (1 << 8) != 0 { try skipNotificationSound(reader: &reader) }
        if flags & (1 << 9) != 0 { try skipNotificationSound(reader: &reader) }
        if flags & (1 << 10) != 0 { try skipNotificationSound(reader: &reader) }
        return muteUntil.map { Int64($0) > Int64(Date().timeIntervalSince1970) } ?? false
    }

    private static func parseNotifyPeer(reader: inout HSTLReader) throws -> HSNativePeer? {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x9fd40bd8:
            return try parsePeer(reader: &reader)
        case 0xb4c83b4c, 0xc007cec3, 0xd612e8ef:
            return nil
        case 0x226e6308:
            let peer = try parsePeer(reader: &reader)
            _ = try reader.int32()
            return peer
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported NotifyPeer constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPeerSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.peerSettings else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PeerSettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 6) != 0 { _ = try reader.int32() }
        if flags & (1 << 9) != 0 {
            _ = try reader.string()
            _ = try reader.int32()
        }
        if flags & (1 << 13) != 0 {
            _ = try reader.int64()
            _ = try reader.string()
        }
        if flags & (1 << 14) != 0 { _ = try reader.int64() }
        if flags & (1 << 15) != 0 { _ = try reader.string() }
        if flags & (1 << 16) != 0 { _ = try reader.string() }
        if flags & (1 << 17) != 0 { _ = try reader.int32() }
        if flags & (1 << 18) != 0 { _ = try reader.int32() }
    }

    private static func skipDraftMessage(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.draftMessageEmpty:
            let flags = try reader.uint32()
            if flags & 1 != 0 {
                _ = try reader.int32()
            }
        case HSNativeMTProtoSchema.draftMessage:
            let flags = try reader.uint32()
            if flags & (1 << 4) != 0 {
                try skipInputReplyTo(reader: &reader)
            }
            _ = try reader.string()
            if flags & (1 << 3) != 0 {
                try skipObjectVector(reader: &reader, name: "MessageEntity")
            }
            if flags & (1 << 5) != 0 {
                try skipUnsupportedObject(reader: &reader, name: "InputMedia")
            }
            _ = try reader.int32()
            if flags & (1 << 7) != 0 {
                _ = try reader.int64()
            }
            if flags & (1 << 8) != 0 {
                try skipSuggestedPost(reader: &reader)
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DraftMessage constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipInputReplyTo(reader: inout HSTLReader) throws {
        _ = try parseInputReplyToMessageID(reader: &reader)
    }

    private static func parseInputReplyToMessageID(reader: inout HSTLReader) throws -> Int64? {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.inputReplyToMessage else {
            throw HSNativeMTProtoError.malformedPacket("unsupported InputReplyTo constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let replyToMessageID = Int64(try reader.int32())
        if flags & (1 << 0) != 0 { _ = try reader.int32() }
        if flags & (1 << 1) != 0 { try skipInputPeer(reader: &reader) }
        if flags & (1 << 2) != 0 { _ = try reader.string() }
        if flags & (1 << 3) != 0 { try skipObjectVector(reader: &reader, name: "MessageEntity") }
        if flags & (1 << 4) != 0 { _ = try reader.int32() }
        if flags & (1 << 5) != 0 { try skipInputPeer(reader: &reader) }
        if flags & (1 << 6) != 0 { _ = try reader.int32() }
        return replyToMessageID > 0 ? replyToMessageID : nil
    }

    private static func skipPrivacyKey(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xbc2eab30, 0x500e6dfa, 0x3d662b7b, 0x39491cc8,
            0x69ec56a3, 0x96151fed, 0xd19ae46d, 0x42ffd42b,
            0x0697f414, 0xa486b761, 0x2000a518, 0x2ca4fdf8,
            0x17d348d2, 0xff7a571b:
            return
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PrivacyKey constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipInputPeer(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.inputPeerEmpty, HSNativeMTProtoSchema.inputPeerSelf:
            return
        case HSNativeMTProtoSchema.inputPeerChat:
            _ = try reader.int64()
        case HSNativeMTProtoSchema.inputPeerUser, HSNativeMTProtoSchema.inputPeerChannel:
            _ = try reader.int64()
            _ = try reader.int64()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported InputPeer constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipInputChannel(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.inputChannelEmpty:
            return
        case HSNativeMTProtoSchema.inputChannel:
            _ = try reader.int64()
            _ = try reader.int64()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported InputChannel constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipChatPhoto(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatPhotoEmpty:
            return
        case HSNativeMTProtoSchema.chatPhoto:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & (1 << 1) != 0 {
                _ = try reader.bytes()
            }
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatPhoto constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipChatAdminRights(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.chatAdminRights else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatAdminRights constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
    }

    private static func skipChatBannedRights(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.chatBannedRights else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatBannedRights constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
        _ = try reader.int32()
    }

    private static func skipChatParticipant(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatParticipant:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.string() }
        case HSNativeMTProtoSchema.chatParticipantLegacy:
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
        case HSNativeMTProtoSchema.chatParticipantCreator:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & 1 != 0 { _ = try reader.string() }
        case HSNativeMTProtoSchema.chatParticipantCreatorLegacy:
            _ = try reader.int64()
        case HSNativeMTProtoSchema.chatParticipantAdmin:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.string() }
        case HSNativeMTProtoSchema.chatParticipantAdminLegacy:
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatParticipant constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseMessageReplyHeader(reader: inout HSTLReader) throws -> Int64? {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.messageReplyHeader else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReplyHeader constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let replyMessageID = flags & (1 << 4) == 0 ? nil : Int64(try reader.int32())
        if flags & (1 << 0) != 0 { _ = try parsePeer(reader: &reader) }
        if flags & (1 << 5) != 0 { try skipMessageFwdHeader(reader: &reader) }
        if flags & (1 << 8) != 0 { try skipMessageMedia(reader: &reader) }
        if flags & (1 << 1) != 0 { _ = try reader.int32() }
        if flags & (1 << 6) != 0 { _ = try reader.string() }
        if flags & (1 << 7) != 0 { try skipObjectVector(reader: &reader, name: "MessageEntity") }
        if flags & (1 << 10) != 0 { _ = try reader.int32() }
        if flags & (1 << 11) != 0 { _ = try reader.int32() }
        return replyMessageID
    }

    private static func skipMessageFwdHeader(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.messageFwdHeader else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageFwdHeader constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 0) != 0 { _ = try parsePeer(reader: &reader) }
        if flags & (1 << 5) != 0 { _ = try reader.string() }
        _ = try reader.int32()
        if flags & (1 << 2) != 0 { _ = try reader.int32() }
        if flags & (1 << 3) != 0 { _ = try reader.string() }
        if flags & (1 << 4) != 0 {
            _ = try parsePeer(reader: &reader)
            _ = try reader.int32()
        }
        if flags & (1 << 8) != 0 { _ = try parsePeer(reader: &reader) }
        if flags & (1 << 9) != 0 { _ = try reader.string() }
        if flags & (1 << 10) != 0 { _ = try reader.int32() }
        if flags & (1 << 6) != 0 { _ = try reader.string() }
    }

    private static func parseMessageMedia(reader: inout HSTLReader) throws -> HSMessageMedia? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.messageMediaEmpty,
            HSNativeMTProtoSchema.messageMediaUnsupported:
            return nil
        case HSNativeMTProtoSchema.messageMediaPhoto:
            let flags = try reader.uint32()
            let media = flags & 1 != 0 ? try parsePhotoMedia(reader: &reader) : nil
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
            return media
        case HSNativeMTProtoSchema.messageMediaDocument:
            let flags = try reader.uint32()
            let media = flags & 1 != 0 ? try parseDocumentMedia(reader: &reader) : nil
            if flags & (1 << 5) != 0 { try skipObjectVector(reader: &reader, name: "Document") }
            if flags & (1 << 9) != 0 { try skipPhoto(reader: &reader) }
            if flags & (1 << 10) != 0 { _ = try reader.int32() }
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
            return media
        case HSNativeMTProtoSchema.messageMediaContact:
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.int64()
            return nil
        case HSNativeMTProtoSchema.messageMediaGeo:
            try skipGeoPoint(reader: &reader)
            return nil
        case HSNativeMTProtoSchema.messageMediaGeoLive:
            let flags = try reader.uint32()
            try skipGeoPoint(reader: &reader)
            if flags & 1 != 0 { _ = try reader.int32() }
            _ = try reader.int32()
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
            return nil
        case HSNativeMTProtoSchema.messageMediaVenue:
            try skipGeoPoint(reader: &reader)
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
            return nil
        case HSNativeMTProtoSchema.messageMediaWebPage:
            _ = try reader.uint32()
            return try parseWebPageMedia(reader: &reader)
        case HSNativeMTProtoSchema.messageMediaDice:
            let flags = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.string()
            if flags & 1 != 0 {
                try skipUnsupportedObject(reader: &reader, name: "messages.EmojiGameOutcome")
            }
            return nil
        case HSNativeMTProtoSchema.messageMediaStory:
            let flags = try reader.uint32()
            _ = try parsePeer(reader: &reader)
            _ = try reader.int32()
            if flags & 1 != 0 {
                try skipStoryItem(reader: &reader)
            }
            return nil
        case HSNativeMTProtoSchema.messageMediaPaidMedia:
            _ = try reader.int64()
            try skipObjectVector(reader: &reader, name: "MessageExtendedMedia")
            return nil
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageMedia constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipMessageMedia(reader: inout HSTLReader) throws {
        _ = try parseMessageMedia(reader: &reader)
    }

    private static func parsePhotoMedia(reader: inout HSTLReader) throws -> HSMessageMedia? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.photoEmpty:
            _ = try reader.int64()
            return HSMessageMedia(kind: .photo, fileName: nil, mimeType: "image/jpeg", size: nil, width: nil, height: nil, duration: nil)
        case HSNativeMTProtoSchema.photo:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let accessHash = try reader.int64()
            let fileReference = try reader.bytes()
            _ = try reader.int32()
            let size = try parsePhotoSizeVector(reader: &reader)
            if flags & (1 << 1) != 0 {
                try skipObjectVector(reader: &reader, name: "VideoSize")
            }
            let dcID = Int(try reader.int32())
            let thumbSize = size?.type ?? ""
            let location = HSMessageMediaLocation(
                kind: .photo,
                id: id,
                accessHash: accessHash,
                fileReference: fileReference,
                dcID: dcID,
                thumbnailSize: thumbSize
            )
            return HSMessageMedia(
                kind: .photo,
                fileName: nil,
                mimeType: "image/jpeg",
                size: size?.bytes,
                width: size?.width,
                height: size?.height,
                duration: nil,
                location: thumbSize.isEmpty ? nil : location
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Photo constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parsePhotoSizeVector(reader: inout HSTLReader) throws -> HSNativeParsedMediaSize? {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected PhotoSize vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative PhotoSize vector count")
        }
        var best: HSNativeParsedMediaSize?
        for _ in 0..<count {
            if let size = try parsePhotoSizeMetadata(reader: &reader) {
                best = preferredMediaSize(best, size)
            }
        }
        return best
    }

    private static func parsePhotoSizeMetadata(reader: inout HSTLReader) throws -> HSNativeParsedMediaSize? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.photoSizeEmpty:
            _ = try reader.string()
            return nil
        case HSNativeMTProtoSchema.photoSize:
            let type = try reader.string()
            let width = Int(try reader.int32())
            let height = Int(try reader.int32())
            let bytes = Int64(try reader.int32())
            return HSNativeParsedMediaSize(type: type, width: width, height: height, bytes: bytes)
        case HSNativeMTProtoSchema.photoSizeProgressive:
            let type = try reader.string()
            let width = Int(try reader.int32())
            let height = Int(try reader.int32())
            let bytes = try parseInt32VectorMax(reader: &reader).map(Int64.init)
            return HSNativeParsedMediaSize(type: type, width: width, height: height, bytes: bytes)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PhotoSize constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDocumentMedia(reader: inout HSTLReader) throws -> HSMessageMedia? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.documentEmpty:
            _ = try reader.int64()
            return HSMessageMedia(kind: .unknown, fileName: nil, mimeType: nil, size: nil, width: nil, height: nil, duration: nil)
        case HSNativeMTProtoSchema.document:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let accessHash = try reader.int64()
            let fileReference = try reader.bytes()
            _ = try reader.int32()
            let mimeType = try reader.string()
            let byteSize = try reader.int64()
            let thumbnail = flags & 1 != 0 ? try parsePhotoSizeVector(reader: &reader) : nil
            if flags & (1 << 1) != 0 {
                try skipObjectVector(reader: &reader, name: "VideoSize")
            }
            let dcID = Int(try reader.int32())
            let attributes = try parseDocumentAttributeVector(reader: &reader)
            let kind = documentMediaKind(mimeType: mimeType, attributes: attributes)
            return HSMessageMedia(
                kind: kind,
                fileName: attributes.fileName,
                mimeType: mimeType.isEmpty ? nil : mimeType,
                size: byteSize,
                width: attributes.width ?? thumbnail?.width,
                height: attributes.height ?? thumbnail?.height,
                duration: attributes.duration,
                waveform: attributes.waveform,
                location: HSMessageMediaLocation(
                    kind: .document,
                    id: id,
                    accessHash: accessHash,
                    fileReference: fileReference,
                    dcID: dcID,
                    thumbnailSize: ""
                )
            )
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Document constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDocumentAttributeVector(reader: inout HSTLReader) throws -> HSNativeParsedDocumentAttributes {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected DocumentAttribute vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative DocumentAttribute vector count")
        }
        var attributes = HSNativeParsedDocumentAttributes()
        for _ in 0..<count {
            let next = try parseDocumentAttributeMetadata(reader: &reader)
            mergeDocumentAttribute(next, into: &attributes)
        }
        return attributes
    }

    private static func parseDocumentAttributeMetadata(reader: inout HSTLReader) throws -> HSNativeParsedDocumentAttributes {
        let constructor = try reader.uint32()
        var attributes = HSNativeParsedDocumentAttributes()
        switch constructor {
        case 0x6c37c15c:
            attributes.width = Int(try reader.int32())
            attributes.height = Int(try reader.int32())
        case 0x11b58939:
            attributes.isAnimated = true
        case 0x9801d2f7:
            break
        case 0x6319d612:
            let flags = try reader.uint32()
            attributes.isSticker = true
            _ = try reader.string()
            try skipInputStickerSet(reader: &reader)
            if flags & 1 != 0 { try skipMaskCoords(reader: &reader) }
        case 0x43c57c48:
            let flags = try reader.uint32()
            attributes.isVideo = true
            attributes.duration = try reader.double()
            attributes.width = Int(try reader.int32())
            attributes.height = Int(try reader.int32())
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
            if flags & (1 << 4) != 0 { _ = try reader.double() }
            if flags & (1 << 5) != 0 { _ = try reader.string() }
        case 0x9852f9c6:
            let flags = try reader.uint32()
            attributes.isAudio = true
            attributes.isVoice = flags & (1 << 10) != 0
            attributes.duration = Double(try reader.int32())
            if flags & 1 != 0 { _ = try reader.string() }
            if flags & (1 << 1) != 0 { _ = try reader.string() }
            if flags & (1 << 2) != 0 { attributes.waveform = try reader.bytes() }
        case 0x15590068:
            attributes.fileName = try reader.string()
        case 0xfd149899:
            _ = try reader.uint32()
            attributes.isCustomEmoji = true
            _ = try reader.string()
            try skipInputStickerSet(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DocumentAttribute constructor 0x\(String(constructor, radix: 16))")
        }
        return attributes
    }

    private static func mergeDocumentAttribute(_ next: HSNativeParsedDocumentAttributes, into attributes: inout HSNativeParsedDocumentAttributes) {
        attributes.fileName = next.fileName ?? attributes.fileName
        attributes.width = next.width ?? attributes.width
        attributes.height = next.height ?? attributes.height
        attributes.duration = next.duration ?? attributes.duration
        attributes.isVideo = attributes.isVideo || next.isVideo
        attributes.isAnimated = attributes.isAnimated || next.isAnimated
        attributes.isAudio = attributes.isAudio || next.isAudio
        attributes.isVoice = attributes.isVoice || next.isVoice
        attributes.waveform = next.waveform ?? attributes.waveform
        attributes.isSticker = attributes.isSticker || next.isSticker
        attributes.isCustomEmoji = attributes.isCustomEmoji || next.isCustomEmoji
    }

    private static func documentMediaKind(mimeType: String, attributes: HSNativeParsedDocumentAttributes) -> HSMessageMedia.MediaKind {
        let normalizedMime = mimeType.lowercased()
        if attributes.isSticker || attributes.isCustomEmoji {
            return .sticker
        }
        if attributes.isAnimated || normalizedMime == "image/gif" {
            return .gif
        }
        if attributes.isVideo || normalizedMime.hasPrefix("video/") {
            return .video
        }
        if attributes.isVoice {
            return .voice
        }
        if attributes.isAudio || normalizedMime.hasPrefix("audio/") {
            return .audio
        }
        return normalizedMime.isEmpty ? .unknown : .file
    }

    private static func preferredMediaSize(_ current: HSNativeParsedMediaSize?, _ candidate: HSNativeParsedMediaSize) -> HSNativeParsedMediaSize {
        guard let current else {
            return candidate
        }
        let currentScore = current.bytes ?? mediaPixelCount(current)
        let candidateScore = candidate.bytes ?? mediaPixelCount(candidate)
        return candidateScore > currentScore ? candidate : current
    }

    private static func mediaPixelCount(_ size: HSNativeParsedMediaSize) -> Int64 {
        guard let width = size.width, let height = size.height else {
            return 0
        }
        return Int64(max(0, width)) * Int64(max(0, height))
    }

    private static func parseInt32VectorMax(reader: inout HSTLReader) throws -> Int32? {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector<int>, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative vector<int> count")
        }
        var maxValue: Int32?
        for _ in 0..<count {
            let value = try reader.int32()
            if maxValue == nil || value > maxValue! {
                maxValue = value
            }
        }
        return maxValue
    }

    private static func skipReplyMarkup(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xa03e5b85:
            _ = try reader.uint32()
        case 0x86b40b08:
            let flags = try reader.uint32()
            if flags & (1 << 3) != 0 { _ = try reader.string() }
        case 0x85dd99d1:
            let flags = try reader.uint32()
            try skipObjectVector(reader: &reader, name: "KeyboardButtonRow")
            if flags & (1 << 3) != 0 { _ = try reader.string() }
        case 0x48a30254:
            try skipObjectVector(reader: &reader, name: "KeyboardButtonRow")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ReplyMarkup constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipObjectVector(reader: inout HSTLReader, name: String) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected \(name) vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative \(name) vector count")
        }
        for _ in 0..<count {
            switch name {
            case "MessageEntity":
                try skipMessageEntity(reader: &reader)
            case "Document":
                try skipDocument(reader: &reader)
            case "Photo":
                try skipPhoto(reader: &reader)
            case "PhotoSize":
                try skipPhotoSize(reader: &reader)
            case "VideoSize":
                try skipVideoSize(reader: &reader)
            case "DocumentAttribute":
                try skipDocumentAttribute(reader: &reader)
            case "ReactionCount":
                try skipReactionCount(reader: &reader)
            case "MessagePeerReaction":
                try skipMessagePeerReaction(reader: &reader)
            case "MessageReactor":
                try skipMessageReactor(reader: &reader)
            case "PrivacyRule":
                _ = try parsePrivacyRuleKind(reader: &reader)
            case "Peer":
                _ = try parsePeer(reader: &reader)
            case "KeyboardButtonRow":
                try skipKeyboardButtonRow(reader: &reader)
            case "KeyboardButton":
                try skipKeyboardButton(reader: &reader)
            case "MessageExtendedMedia":
                try skipMessageExtendedMedia(reader: &reader)
            case "GroupCallParticipantVideoSourceGroup":
                try skipGroupCallParticipantVideoSourceGroup(reader: &reader)
            case "BotInfo":
                try skipBotInfo(reader: &reader)
            case "BotCommand":
                try skipBotCommand(reader: &reader)
            case "BusinessWeeklyOpen":
                try skipBusinessWeeklyOpen(reader: &reader)
            case "StoryItem":
                try skipStoryItem(reader: &reader)
            case "WebPageAttribute":
                try skipWebPageAttribute(reader: &reader)
            case "PageBlock":
                try skipPageBlock(reader: &reader)
            case "RichText":
                try skipRichText(reader: &reader)
            case "PageListItem":
                try skipPageListItem(reader: &reader)
            case "PageListOrderedItem":
                try skipPageListOrderedItem(reader: &reader)
            case "PageTableRow":
                try skipPageTableRow(reader: &reader)
            case "PageTableCell":
                try skipPageTableCell(reader: &reader)
            case "PageRelatedArticle":
                try skipPageRelatedArticle(reader: &reader)
            case "StarGiftAttribute":
                try skipStarGiftAttribute(reader: &reader)
            default:
                try skipUnsupportedObject(reader: &reader, name: name)
            }
        }
    }

    private static func skipMessageEntity(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xbb92ba95, 0xfa04579d, 0x6f635b0d, 0x6cef8ac7, 0x6ed02538,
            0x64e475c2, 0xbd610bc9, 0x826f8b60, 0x28a20571, 0x9b69e34b,
            0x4c4e743f, 0x9c4e7e8b, 0xbf0693d4, 0x761e6af4, 0x32ca960f:
            _ = try reader.int32()
            _ = try reader.int32()
        case 0x73924be0:
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.string()
        case 0x76a6d327:
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.string()
        case 0xdc7b1140:
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int64()
        case 0xc8cf05f8:
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int64()
        case 0xf1ccaaac:
            _ = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.int32()
        case 0x904ac7c7:
            _ = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageEntity constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipMessageReplies(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x83d60fc2 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReplies constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int32()
        _ = try reader.int32()
        if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "Peer") }
        if flags & 1 != 0 { _ = try reader.int64() }
        if flags & (1 << 2) != 0 { _ = try reader.int32() }
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
    }

    private static func skipMessageReactions(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x0a339f0b else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReactions constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        try skipObjectVector(reader: &reader, name: "ReactionCount")
        if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "MessagePeerReaction") }
        if flags & (1 << 4) != 0 { try skipObjectVector(reader: &reader, name: "MessageReactor") }
    }

    private static func parseMessageReactions(reader: inout HSTLReader) throws -> [HSMessageReaction] {
        let constructor = try reader.uint32()
        guard constructor == 0x0a339f0b else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReactions constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let reactions = try parseVector(reader: &reader, elementName: "ReactionCount", parseReactionCount)
        if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "MessagePeerReaction") }
        if flags & (1 << 4) != 0 { try skipObjectVector(reader: &reader, name: "MessageReactor") }
        return reactions.filter { $0.count > 0 }
    }

    private static func parseMessageRepliesCount(reader: inout HSTLReader) throws -> Int {
        let constructor = try reader.uint32()
        guard constructor == 0x83d60fc2 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReplies constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let count = Int(try reader.int32())
        _ = try reader.int32()
        if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "Peer") }
        if flags & 1 != 0 { _ = try reader.int64() }
        if flags & (1 << 2) != 0 { _ = try reader.int32() }
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
        return count
    }

    private static func parseReactionCount(reader: inout HSTLReader) throws -> HSMessageReaction {
        let constructor = try reader.uint32()
        guard constructor == 0xa3d1cb80 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ReactionCount constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        let chosenOrder = flags & 1 == 0 ? nil : Int(try reader.int32())
        let reaction = try parseReaction(reader: &reader)
        let count = Int(try reader.int32())
        return HSMessageReaction(
            value: reaction,
            count: max(0, count),
            isSelected: chosenOrder != nil,
            chosenOrder: chosenOrder
        )
    }

    private static func parseReaction(reader: inout HSTLReader) throws -> String {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x79f5d419:
            return ""
        case 0x523da4eb:
            return "⭐️"
        case 0x1b2286b8:
            return try reader.string()
        case 0x8935fc73:
            return "custom:\(try reader.int64())"
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Reaction constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipReactionCount(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xa3d1cb80 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ReactionCount constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 { _ = try reader.int32() }
        try skipReaction(reader: &reader)
        _ = try reader.int32()
    }

    private static func skipReaction(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x79f5d419, 0x523da4eb:
            return
        case 0x1b2286b8:
            _ = try reader.string()
        case 0x8935fc73:
            _ = try reader.int64()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Reaction constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipReactionVector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected Reaction vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative Reaction vector count")
        }
        for _ in 0..<count {
            try skipReaction(reader: &reader)
        }
    }

    private static func skipMessagePeerReaction(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x8c79b63c else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessagePeerReaction constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
        _ = try parsePeer(reader: &reader)
        _ = try reader.int32()
        try skipReaction(reader: &reader)
    }

    private static func skipMessageReactor(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x4ba3a95a else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageReactor constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 3) != 0 {
            _ = try parsePeer(reader: &reader)
        }
        _ = try reader.int32()
    }

    private static func parseSendMessageAction(reader: inout HSTLReader) throws -> (kind: HSInputActivityKind, progress: Int?) {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.sendMessageCancelAction:
            return (.cancel, nil)
        case HSNativeMTProtoSchema.sendMessageTypingAction:
            return (.typing, nil)
        case HSNativeMTProtoSchema.sendMessageRecordAudioAction:
            return (.recordingVoice, nil)
        case HSNativeMTProtoSchema.sendMessageRecordVideoAction:
            return (.recordingVideo, nil)
        case HSNativeMTProtoSchema.sendMessageRecordRoundAction:
            return (.recordingVideo, nil)
        case HSNativeMTProtoSchema.sendMessageChooseStickerAction:
            return (.choosingSticker, nil)
        case HSNativeMTProtoSchema.sendMessageUploadAudioAction:
            return (.uploadingVoice, Int(try reader.int32()))
        case HSNativeMTProtoSchema.sendMessageUploadDocumentAction:
            return (.uploadingFile, Int(try reader.int32()))
        case HSNativeMTProtoSchema.sendMessageUploadPhotoAction:
            return (.uploadingPhoto, Int(try reader.int32()))
        case HSNativeMTProtoSchema.sendMessageUploadRoundAction:
            return (.uploadingInstantVideo, Int(try reader.int32()))
        case HSNativeMTProtoSchema.sendMessageUploadVideoAction:
            return (.uploadingVideo, Int(try reader.int32()))
        case 0x176f8ba1, 0x628cbc6f, 0xdd6a8f48, 0xd92c2285:
            return (.typing, nil)
        case 0xdbda9246:
            _ = try reader.int32()
            return (.uploadingFile, nil)
        case 0x25972bcb:
            _ = try reader.string()
            _ = try reader.int32()
            try skipDataJSON(reader: &reader)
            return (.typing, nil)
        case 0xb665902e:
            _ = try reader.string()
            return (.typing, nil)
        case 0x376d975c:
            _ = try reader.int64()
            try skipTextWithEntities(reader: &reader)
            return (.typing, nil)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported SendMessageAction constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipSendMessageAction(reader: inout HSTLReader) throws {
        _ = try parseSendMessageAction(reader: &reader)
    }

    private static func inputActivity(
        dialogID: Int64,
        userID: Int64,
        action: (kind: HSInputActivityKind, progress: Int?)
    ) -> HSInputActivity {
        HSInputActivity(
            dialogID: dialogID,
            userID: userID,
            kind: action.kind,
            progress: action.progress,
            expiresAt: Date().addingTimeInterval(action.kind == .cancel ? 0 : 6)
        )
    }

    private static func skipDataJSON(reader: inout HSTLReader) throws {
        _ = try parseDataJSON(reader: &reader)
    }

    private static func parseDataJSON(reader: inout HSTLReader) throws -> String {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.dataJSON else {
            throw HSNativeMTProtoError.malformedPacket("unsupported DataJSON constructor 0x\(String(constructor, radix: 16))")
        }
        return try reader.string()
    }

    private static func skipFactCheck(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xb89bfccf else {
            throw HSNativeMTProtoError.malformedPacket("unsupported FactCheck constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 1) != 0 {
            _ = try reader.string()
            try skipTextWithEntities(reader: &reader)
        }
        _ = try reader.int64()
    }

    private static func skipSuggestedPost(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xe8e37e5 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported SuggestedPost constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 3) != 0 { try skipStarsAmount(reader: &reader) }
        if flags & (1 << 0) != 0 { _ = try reader.int32() }
    }

    private static func skipStarsAmount(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xbbb6b4a3 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported StarsAmount constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int64()
        _ = try reader.int32()
    }

    private static func skipRecentStory(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x711d692d else {
            throw HSNativeMTProtoError.malformedPacket("unsupported RecentStory constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 1) != 0 {
            _ = try reader.int32()
        }
    }

    private static func skipMessageAction(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xb6aef7b0, 0x95e3fbef, 0x94bd38ed, 0x9fbab604, 0x4792929b, 0xf3f25f76, 0xebbca3cb:
            return
        case 0xbd47cbad:
            _ = try reader.string()
            try skipInt64Vector(reader: &reader)
        case 0xb5a1ce5a, 0x95d2ac92, 0xfae69f56, 0xb4c38cb5:
            _ = try reader.string()
        case 0x7fcb13a8, 0x57de635e:
            try skipPhoto(reader: &reader)
        case 0x15cefd00:
            try skipInt64Vector(reader: &reader)
        case 0xa43f30cc, 0x31224c3, 0xe1037f92:
            _ = try reader.int64()
        case 0xea3948e9:
            _ = try reader.string()
            _ = try reader.int64()
        case 0x92a72876:
            _ = try reader.int64()
            _ = try reader.int32()
        case 0x80e11a7f:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & 1 != 0 { try skipUnsupportedObject(reader: &reader, name: "PhoneCallDiscardReason") }
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
        case 0x98e0d697:
            _ = try parsePeer(reader: &reader)
            _ = try parsePeer(reader: &reader)
            _ = try reader.int32()
        case 0x3c134d7b:
            let flags = try reader.uint32()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.int64() }
        case 0xd999256:
            let flags = try reader.uint32()
            _ = try reader.string()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.int64() }
        case 0xc0944820:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.string() }
            if flags & (1 << 1) != 0 { _ = try reader.int64() }
            if flags & (1 << 2) != 0 { try skipBool(reader: &reader) }
            if flags & (1 << 3) != 0 { try skipBool(reader: &reader) }
        case 0x47dd8079:
            _ = try reader.string()
            _ = try reader.string()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageAction constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBool(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x997275b5 || constructor == 0xbc799737 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Bool constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseBool(reader: inout HSTLReader) throws -> Bool {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.boolTrue:
            return true
        case HSNativeMTProtoSchema.boolFalse:
            return false
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Bool constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipNotificationSound(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x97e8bebe, 0x6f0c34df:
            return
        case 0x830b9ae4:
            _ = try reader.string()
            _ = try reader.string()
        case 0xff6c8049:
            _ = try reader.int64()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported NotificationSound constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPhoto(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.photoEmpty:
            _ = try reader.int64()
        case HSNativeMTProtoSchema.photo:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.bytes()
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "PhotoSize")
            if flags & (1 << 1) != 0 {
                try skipObjectVector(reader: &reader, name: "VideoSize")
            }
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Photo constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPhotoSize(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.photoSizeEmpty:
            _ = try reader.string()
        case HSNativeMTProtoSchema.photoSize:
            _ = try reader.string()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
        case HSNativeMTProtoSchema.photoSizeProgressive:
            _ = try reader.string()
            _ = try reader.int32()
            _ = try reader.int32()
            try skipInt32Vector(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PhotoSize constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipVideoSize(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xde33b094:
            let flags = try reader.uint32()
            _ = try reader.string()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & 1 != 0 {
                _ = try reader.raw(count: 8)
            }
        case 0xf85c413c:
            _ = try reader.int64()
            try skipInt32Vector(reader: &reader)
        case 0xda082fe:
            try skipInputStickerSet(reader: &reader)
            _ = try reader.int64()
            try skipInt32Vector(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported VideoSize constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipStickerSet(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x2dd14edc, 0xd7df217a:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int32() }
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.string()
            _ = try reader.string()
            if flags & (1 << 4) != 0 {
                try skipObjectVector(reader: &reader, name: "PhotoSize")
                _ = try reader.int32()
                _ = try reader.int32()
            }
            if constructor == 0x2dd14edc, flags & (1 << 8) != 0 {
                _ = try reader.int64()
            }
            _ = try reader.int32()
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported StickerSet constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDocumentID(reader: inout HSTLReader) throws -> Int64 {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.documentEmpty:
            return try reader.int64()
        case HSNativeMTProtoSchema.document:
            let flags = try reader.uint32()
            let id = try reader.int64()
            _ = try reader.int64()
            _ = try reader.bytes()
            _ = try reader.int32()
            _ = try reader.string()
            _ = try reader.int64()
            if flags & 1 != 0 {
                try skipObjectVector(reader: &reader, name: "PhotoSize")
            }
            if flags & (1 << 1) != 0 {
                try skipObjectVector(reader: &reader, name: "VideoSize")
            }
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "DocumentAttribute")
            return id
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Document constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseDocumentIDVectorFirst(reader: inout HSTLReader) throws -> Int64? {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected Document vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative Document vector count")
        }
        var firstID: Int64?
        for index in 0..<count {
            let id = try parseDocumentID(reader: &reader)
            if index == 0 {
                firstID = id
            }
        }
        return firstID
    }

    private static func skipStickerPackVector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected StickerPack vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative StickerPack vector count")
        }
        for _ in 0..<count {
            let constructor = try reader.uint32()
            guard constructor == 0x12b299d4 else {
                throw HSNativeMTProtoError.malformedPacket("unsupported StickerPack constructor 0x\(String(constructor, radix: 16))")
            }
            _ = try reader.string()
            try skipInt64Vector(reader: &reader)
        }
    }

    private static func skipStickerKeywordVector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected StickerKeyword vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative StickerKeyword vector count")
        }
        for _ in 0..<count {
            let constructor = try reader.uint32()
            guard constructor == 0xfcfeb29c else {
                throw HSNativeMTProtoError.malformedPacket("unsupported StickerKeyword constructor 0x\(String(constructor, radix: 16))")
            }
            _ = try reader.int64()
            _ = try parseStringVector(reader: &reader)
        }
    }

    private static func skipDocument(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.documentEmpty:
            _ = try reader.int64()
        case HSNativeMTProtoSchema.document:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.bytes()
            _ = try reader.int32()
            _ = try reader.string()
            _ = try reader.int64()
            if flags & 1 != 0 {
                try skipObjectVector(reader: &reader, name: "PhotoSize")
            }
            if flags & (1 << 1) != 0 {
                try skipObjectVector(reader: &reader, name: "VideoSize")
            }
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "DocumentAttribute")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported Document constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipDocumentAttribute(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x6c37c15c:
            _ = try reader.int32()
            _ = try reader.int32()
        case 0x11b58939, 0x9801d2f7:
            return
        case 0x6319d612:
            let flags = try reader.uint32()
            _ = try reader.string()
            try skipInputStickerSet(reader: &reader)
            if flags & 1 != 0 { try skipMaskCoords(reader: &reader) }
        case 0x43c57c48:
            let flags = try reader.uint32()
            _ = try reader.raw(count: 8)
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
            if flags & (1 << 4) != 0 { _ = try reader.raw(count: 8) }
            if flags & (1 << 5) != 0 { _ = try reader.string() }
        case 0x9852f9c6:
            let flags = try reader.uint32()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.string() }
            if flags & (1 << 1) != 0 { _ = try reader.string() }
            if flags & (1 << 2) != 0 { _ = try reader.bytes() }
        case 0x15590068:
            _ = try reader.string()
        case 0xfd149899:
            _ = try reader.uint32()
            _ = try reader.string()
            try skipInputStickerSet(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported DocumentAttribute constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBotInfo(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x4d8a0299, 0x36607333, 0x82437e74, 0x8f300b57:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int64() }
            if flags & (1 << 1) != 0 { _ = try reader.string() }
            if flags & (1 << 4) != 0 { try skipPhoto(reader: &reader) }
            if flags & (1 << 5) != 0 { try skipDocument(reader: &reader) }
            if flags & (1 << 2) != 0 { try skipObjectVector(reader: &reader, name: "BotCommand") }
            if flags & (1 << 3) != 0 { try skipBotMenuButton(reader: &reader) }
            if flags & (1 << 7) != 0 { _ = try reader.string() }
            if flags & (1 << 8) != 0 { try skipBotAppSettings(reader: &reader) }
            if flags & (1 << 9) != 0 { try skipBotVerifierSettings(reader: &reader) }
        case 0xe4169b5d:
            _ = try reader.int64()
            _ = try reader.string()
            try skipObjectVector(reader: &reader, name: "BotCommand")
            try skipBotMenuButton(reader: &reader)
        case 0x1b74b335:
            _ = try reader.int64()
            _ = try reader.string()
            try skipObjectVector(reader: &reader, name: "BotCommand")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported BotInfo constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBotCommand(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xc27ac8c7 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BotCommand constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.string()
        _ = try reader.string()
    }

    private static func skipBotMenuButton(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x7533a588, 0x4258c205:
            return
        case 0xc7b57ce6:
            _ = try reader.string()
            _ = try reader.string()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported BotMenuButton constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBotAppSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xc99b1950 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BotAppSettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 { _ = try reader.bytes() }
        if flags & (1 << 1) != 0 { _ = try reader.int32() }
        if flags & (1 << 2) != 0 { _ = try reader.int32() }
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
        if flags & (1 << 4) != 0 { _ = try reader.int32() }
    }

    private static func skipBotVerifierSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xb0cd6617 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BotVerifierSettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int64()
        _ = try reader.string()
        if flags & 1 != 0 { _ = try reader.string() }
    }

    private static func skipInputStickerSet(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xffb62b95, 0x028703c8, 0xcde3739, 0xc88b3b02, 0x4c4d4ce, 0x29d0f5ee, 0x44c1f8e9, 0x49748553, 0x1cf671a0:
            return
        case 0x9de7a269:
            _ = try reader.int64()
            _ = try reader.int64()
        case 0x861cc8a0, 0xe67f520e:
            _ = try reader.string()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported InputStickerSet constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipMaskCoords(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xaed6dbb2 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported MaskCoords constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int32()
        _ = try reader.raw(count: 8)
        _ = try reader.raw(count: 8)
        _ = try reader.raw(count: 8)
    }

    private static func skipGeoPoint(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.geoPointEmpty:
            return
        case HSNativeMTProtoSchema.geoPoint:
            let flags = try reader.uint32()
            _ = try reader.raw(count: 8)
            _ = try reader.raw(count: 8)
            _ = try reader.int64()
            if flags & 1 != 0 {
                _ = try reader.int32()
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported GeoPoint constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseWebPageMedia(reader: inout HSTLReader) throws -> HSMessageMedia? {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.webPageEmpty:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let url = flags & 1 != 0 ? try reader.string() : nil
            let preview = HSWebPagePreview(
                id: id,
                url: url,
                displayURL: url,
                type: nil,
                siteName: nil,
                title: nil,
                description: nil,
                author: nil,
                duration: nil,
                embedURL: nil,
                embedType: nil,
                embedWidth: nil,
                embedHeight: nil,
                photo: nil,
                document: nil,
                isPending: false
            )
            return webPageMedia(from: preview)
        case HSNativeMTProtoSchema.webPagePending:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let url = flags & 1 != 0 ? try reader.string() : nil
            _ = try reader.int32()
            let preview = HSWebPagePreview(
                id: id,
                url: url,
                displayURL: url,
                type: nil,
                siteName: nil,
                title: nil,
                description: nil,
                author: nil,
                duration: nil,
                embedURL: nil,
                embedType: nil,
                embedWidth: nil,
                embedHeight: nil,
                photo: nil,
                document: nil,
                isPending: true
            )
            return webPageMedia(from: preview)
        case HSNativeMTProtoSchema.webPageNotModified:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try reader.int32() }
            return nil
        case HSNativeMTProtoSchema.webPage:
            let flags = try reader.uint32()
            let id = try reader.int64()
            let url = try reader.string()
            let displayURL = try reader.string()
            _ = try reader.int32()
            let type = try readOptionalString(reader: &reader, flags: flags, bit: 0)
            let siteName = try readOptionalString(reader: &reader, flags: flags, bit: 1)
            let title = try readOptionalString(reader: &reader, flags: flags, bit: 2)
            let description = try readOptionalString(reader: &reader, flags: flags, bit: 3)
            let photo = flags & (1 << 4) != 0 ? try parsePhotoMedia(reader: &reader).map { webPagePreviewMedia(from: $0) } : nil
            var embedURL: String?
            var embedType: String?
            if flags & (1 << 5) != 0 {
                embedURL = try reader.string()
                embedType = try reader.string()
            }
            var embedWidth: Int?
            var embedHeight: Int?
            if flags & (1 << 6) != 0 {
                embedWidth = Int(try reader.int32())
                embedHeight = Int(try reader.int32())
            }
            let duration = flags & (1 << 7) != 0 ? Double(try reader.int32()) : nil
            let author = try readOptionalString(reader: &reader, flags: flags, bit: 8)
            let document = flags & (1 << 9) != 0 ? try parseDocumentMedia(reader: &reader).map { webPagePreviewMedia(from: $0) } : nil
            if flags & (1 << 10) != 0 { try skipPage(reader: &reader) }
            if flags & (1 << 12) != 0 { try skipObjectVector(reader: &reader, name: "WebPageAttribute") }
            let preview = HSWebPagePreview(
                id: id,
                url: url,
                displayURL: displayURL,
                type: type,
                siteName: siteName,
                title: title,
                description: description,
                author: author,
                duration: duration,
                embedURL: embedURL,
                embedType: embedType,
                embedWidth: embedWidth,
                embedHeight: embedHeight,
                photo: photo,
                document: document,
                isPending: false
            )
            return webPageMedia(from: preview)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported WebPage constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipWebPage(reader: inout HSTLReader) throws {
        _ = try parseWebPageMedia(reader: &reader)
    }

    private static func webPageMedia(from preview: HSWebPagePreview) -> HSMessageMedia {
        let displayTitle = nonEmptyString(preview.title)
            ?? nonEmptyString(preview.siteName)
            ?? nonEmptyString(preview.displayURL)
            ?? nonEmptyString(preview.url)
            ?? "Link Preview"
        let visualMedia = preview.photo ?? preview.document
        return HSMessageMedia(
            kind: .webpage,
            fileName: displayTitle,
            mimeType: nil,
            size: visualMedia?.size,
            width: visualMedia?.width ?? preview.embedWidth,
            height: visualMedia?.height ?? preview.embedHeight,
            duration: preview.duration ?? visualMedia?.duration,
            webPage: preview,
            location: nil
        )
    }

    private static func webPagePreviewMedia(from media: HSMessageMedia) -> HSWebPagePreviewMedia {
        HSWebPagePreviewMedia(
            kind: media.kind,
            mimeType: media.mimeType,
            size: media.size,
            width: media.width,
            height: media.height,
            duration: media.duration,
            location: media.location
        )
    }

    private static func nonEmptyString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func skipPage(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x98657f0d else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Page constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.string()
        try skipObjectVector(reader: &reader, name: "PageBlock")
        try skipObjectVector(reader: &reader, name: "Photo")
        try skipObjectVector(reader: &reader, name: "Document")
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
    }

    private static func skipWebPageAttribute(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.webPageAttributeTheme:
            let flags = try reader.uint32()
            if flags & 1 != 0 { try skipObjectVector(reader: &reader, name: "Document") }
            if flags & (1 << 1) != 0 { try skipThemeSettings(reader: &reader) }
        case HSNativeMTProtoSchema.webPageAttributeStory:
            let flags = try reader.uint32()
            _ = try parsePeer(reader: &reader)
            _ = try reader.int32()
            if flags & 1 != 0 { try skipStoryItem(reader: &reader) }
        case HSNativeMTProtoSchema.webPageAttributeStickerSet:
            _ = try reader.uint32()
            try skipObjectVector(reader: &reader, name: "Document")
        case HSNativeMTProtoSchema.webPageAttributeUniqueStarGift:
            try skipStarGift(reader: &reader)
        case HSNativeMTProtoSchema.webPageAttributeStarGiftAuction:
            try skipStarGift(reader: &reader)
            _ = try reader.int32()
        case HSNativeMTProtoSchema.webPageAttributeStarGiftCollection:
            try skipObjectVector(reader: &reader, name: "Document")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported WebPageAttribute constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipThemeSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xfa58b6d4 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ThemeSettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        try skipBaseTheme(reader: &reader)
        _ = try reader.int32()
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
        if flags & 1 != 0 { try skipInt32Vector(reader: &reader) }
        if flags & (1 << 1) != 0 { try skipWallPaper(reader: &reader) }
    }

    private static func skipBaseTheme(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xc3a12462, 0xfbd81688, 0xb7b31ea8, 0x6d5f77ee, 0x5b11125a:
            return
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported BaseTheme constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipRichText(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xdc3d824f:
            return
        case 0x744694e0:
            _ = try reader.string()
        case 0x6724abc4, 0xd912a59c, 0xc12622c4, 0x9bf8bb95, 0x6c3f19b9,
            0xed6a8504, 0xc7fb5e01, 0x034b8621:
            try skipRichText(reader: &reader)
        case 0x3c2884c1:
            try skipRichText(reader: &reader)
            _ = try reader.string()
            _ = try reader.int64()
        case 0xde5a0dd6:
            try skipRichText(reader: &reader)
            _ = try reader.string()
        case 0x7e6260d7:
            try skipObjectVector(reader: &reader, name: "RichText")
        case 0x1ccb966a:
            try skipRichText(reader: &reader)
            _ = try reader.string()
        case 0x081ccf4f:
            _ = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int32()
        case 0x35553762:
            try skipRichText(reader: &reader)
            _ = try reader.string()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported RichText constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPageCaption(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x6f747657 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PageCaption constructor 0x\(String(constructor, radix: 16))")
        }
        try skipRichText(reader: &reader)
        try skipRichText(reader: &reader)
    }

    private static func skipPageBlock(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x13567e8a, 0xdb20b188:
            return
        case 0x70abc3fd, 0x8ffa9a1f, 0xbfd064ec, 0xf12bb6e1, 0x467a0766,
            0x48870999, 0x1e148390:
            try skipRichText(reader: &reader)
        case 0xbaafe5e0:
            try skipRichText(reader: &reader)
            _ = try reader.int32()
        case 0xc070d93e:
            try skipRichText(reader: &reader)
            _ = try reader.string()
        case 0xce0d37b0:
            _ = try reader.string()
        case 0xe4e88011:
            try skipObjectVector(reader: &reader, name: "PageListItem")
        case 0x263d7c26, 0x4f4456d3:
            try skipRichText(reader: &reader)
            try skipRichText(reader: &reader)
        case 0x1759c560:
            let flags = try reader.uint32()
            _ = try reader.int64()
            try skipPageCaption(reader: &reader)
            if flags & 1 != 0 {
                _ = try reader.string()
                _ = try reader.int64()
            }
        case 0x7c8fe7b6:
            _ = try reader.uint32()
            _ = try reader.int64()
            try skipPageCaption(reader: &reader)
        case 0x39f23300:
            try skipPageBlock(reader: &reader)
        case 0xa8718dc5:
            let flags = try reader.uint32()
            if flags & (1 << 1) != 0 { _ = try reader.string() }
            if flags & (1 << 2) != 0 { _ = try reader.string() }
            if flags & (1 << 4) != 0 { _ = try reader.int64() }
            if flags & (1 << 5) != 0 {
                _ = try reader.int32()
                _ = try reader.int32()
            }
            try skipPageCaption(reader: &reader)
        case 0xf259a80b:
            _ = try reader.string()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.string()
            _ = try reader.int32()
            try skipObjectVector(reader: &reader, name: "PageBlock")
            try skipPageCaption(reader: &reader)
        case 0x65a0fa4d, 0x031f9590:
            try skipObjectVector(reader: &reader, name: "PageBlock")
            try skipPageCaption(reader: &reader)
        case 0xef1751b5:
            _ = try parseChat(reader: &reader)
        case 0x804361ea:
            _ = try reader.int64()
            try skipPageCaption(reader: &reader)
        case 0xbf4dea82:
            _ = try reader.uint32()
            try skipRichText(reader: &reader)
            try skipObjectVector(reader: &reader, name: "PageTableRow")
        case 0x9a8ae1e1:
            try skipObjectVector(reader: &reader, name: "PageListOrderedItem")
        case 0x76768bed:
            _ = try reader.uint32()
            try skipObjectVector(reader: &reader, name: "PageBlock")
            try skipRichText(reader: &reader)
        case 0x16115a96:
            try skipRichText(reader: &reader)
            try skipObjectVector(reader: &reader, name: "PageRelatedArticle")
        case 0xa44f3ef6:
            try skipGeoPoint(reader: &reader)
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            try skipPageCaption(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PageBlock constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPageListItem(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xb92fb6cd:
            try skipRichText(reader: &reader)
        case 0x25e073fc:
            try skipObjectVector(reader: &reader, name: "PageBlock")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PageListItem constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPageListOrderedItem(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x5e068047:
            _ = try reader.string()
            try skipRichText(reader: &reader)
        case 0x98dd8936:
            _ = try reader.string()
            try skipObjectVector(reader: &reader, name: "PageBlock")
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported PageListOrderedItem constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPageTableRow(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xe0c0c5e5 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PageTableRow constructor 0x\(String(constructor, radix: 16))")
        }
        try skipObjectVector(reader: &reader, name: "PageTableCell")
    }

    private static func skipPageTableCell(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x34566b6a else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PageTableCell constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 7) != 0 { try skipRichText(reader: &reader) }
        if flags & (1 << 1) != 0 { _ = try reader.int32() }
        if flags & (1 << 2) != 0 { _ = try reader.int32() }
    }

    private static func skipPageRelatedArticle(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xb390dc08 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PageRelatedArticle constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.string()
        _ = try reader.int64()
        _ = try readOptionalString(reader: &reader, flags: flags, bit: 0)
        _ = try readOptionalString(reader: &reader, flags: flags, bit: 1)
        if flags & (1 << 2) != 0 { _ = try reader.int64() }
        _ = try readOptionalString(reader: &reader, flags: flags, bit: 3)
        if flags & (1 << 4) != 0 { _ = try reader.int32() }
    }

    private static func skipStarGift(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xc62aca28:
            let flags = try reader.uint32()
            _ = try reader.int64()
            try skipDocument(reader: &reader)
            _ = try reader.int64()
            if flags & 1 != 0 {
                _ = try reader.int32()
                _ = try reader.int32()
            }
            if flags & (1 << 4) != 0 { _ = try reader.int64() }
            _ = try reader.int64()
            if flags & (1 << 1) != 0 {
                _ = try reader.int32()
                _ = try reader.int32()
            }
            if flags & (1 << 3) != 0 { _ = try reader.int64() }
            if flags & (1 << 4) != 0 { _ = try reader.int64() }
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 5)
        case 0x6411db89:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try parsePeer(reader: &reader) }
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 1)
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 2)
            try skipObjectVector(reader: &reader, name: "StarGiftAttribute")
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try readOptionalString(reader: &reader, flags: flags, bit: 3)
            if flags & (1 << 4) != 0 { _ = try reader.int64() }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported StarGift constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipStarGiftAttribute(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x39d99013, 0x13acff19:
            _ = try reader.string()
            try skipDocument(reader: &reader)
            _ = try reader.int32()
        case 0xd93d859c:
            _ = try reader.string()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
        case 0xe0bff26c:
            let flags = try reader.uint32()
            if flags & 1 != 0 { _ = try parsePeer(reader: &reader) }
            _ = try parsePeer(reader: &reader)
            _ = try reader.int32()
            if flags & (1 << 1) != 0 { try skipTextWithEntities(reader: &reader) }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported StarGiftAttribute constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipTextWithEntities(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x751f3146 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported TextWithEntities constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.string()
        try skipObjectVector(reader: &reader, name: "MessageEntity")
    }

    private static func skipChatTheme(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xc3dffc04:
            _ = try reader.string()
        case 0x3458f9c8:
            try skipStarGift(reader: &reader)
            try skipThemeSettings(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatTheme constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBusinessWorkHours(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x8c92b098 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessWorkHours constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
        _ = try reader.string()
        try skipObjectVector(reader: &reader, name: "BusinessWeeklyOpen")
    }

    private static func skipBusinessWeeklyOpen(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x120b1ab9 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessWeeklyOpen constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int32()
        _ = try reader.int32()
    }

    private static func skipBusinessLocation(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xac5c1af7 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessLocation constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 { try skipGeoPoint(reader: &reader) }
        _ = try reader.string()
    }

    private static func skipBusinessRecipients(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x21108ff7 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessRecipients constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 4) != 0 { try skipInt64Vector(reader: &reader) }
    }

    private static func skipBusinessGreetingMessage(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xe519abab else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessGreetingMessage constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int32()
        try skipBusinessRecipients(reader: &reader)
        _ = try reader.int32()
    }

    private static func skipBusinessAwayMessage(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xef156a5c else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessAwayMessage constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
        _ = try reader.int32()
        try skipBusinessAwayMessageSchedule(reader: &reader)
        try skipBusinessRecipients(reader: &reader)
    }

    private static func skipBusinessAwayMessageSchedule(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xc9b9e2b9, 0xc3f2f501:
            return
        case 0xcc4d9ecc:
            _ = try reader.int32()
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessAwayMessageSchedule constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipBusinessIntro(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x5a0a066d else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BusinessIntro constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.string()
        _ = try reader.string()
        if flags & 1 != 0 { try skipDocument(reader: &reader) }
    }

    private static func skipBirthday(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x6c8e1e06 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported Birthday constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int32()
        _ = try reader.int32()
        if flags & 1 != 0 { _ = try reader.int32() }
    }

    private static func skipStarRefProgram(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xdd0c66f2 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported StarRefProgram constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int64()
        _ = try reader.int32()
        if flags & 1 != 0 { _ = try reader.int32() }
        if flags & (1 << 1) != 0 { _ = try reader.int32() }
        if flags & (1 << 2) != 0 { try skipStarsAmount(reader: &reader) }
    }

    private static func skipDisallowedGiftsSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x71f276c4 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported DisallowedGiftsSettings constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.uint32()
    }

    private static func skipStarsRating(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x1b0e4f07 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported StarsRating constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int32()
        _ = try reader.int64()
        _ = try reader.int64()
        if flags & 1 != 0 { _ = try reader.int64() }
    }

    private static func skipStoryItem(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x51e6ee4f:
            _ = try reader.int32()
        case 0xffadc913:
            _ = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
        case 0xedf164f1:
            let flags = try reader.uint32()
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & (1 << 18) != 0 { _ = try parsePeer(reader: &reader) }
            if flags & (1 << 17) != 0 { try skipUnsupportedObject(reader: &reader, name: "StoryFwdHeader") }
            _ = try reader.int32()
            if flags & 1 != 0 { _ = try reader.string() }
            if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "MessageEntity") }
            try skipMessageMedia(reader: &reader)
            if flags & (1 << 14) != 0 { try skipObjectVector(reader: &reader, name: "MediaArea") }
            if flags & (1 << 2) != 0 { try skipObjectVector(reader: &reader, name: "PrivacyRule") }
            if flags & (1 << 3) != 0 { try skipUnsupportedObject(reader: &reader, name: "StoryViews") }
            if flags & (1 << 15) != 0 { try skipReaction(reader: &reader) }
            if flags & (1 << 19) != 0 { try skipInt32Vector(reader: &reader) }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported StoryItem constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipMessageExtendedMedia(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xad628cc8:
            let flags = try reader.uint32()
            if flags & 1 != 0 {
                _ = try reader.int32()
                _ = try reader.int32()
            }
            if flags & (1 << 1) != 0 { try skipPhotoSize(reader: &reader) }
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
        case 0xee479c64:
            try skipMessageMedia(reader: &reader)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported MessageExtendedMedia constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipKeyboardButtonRow(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x77608b83 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported KeyboardButtonRow constructor 0x\(String(constructor, radix: 16))")
        }
        try skipObjectVector(reader: &reader, name: "KeyboardButton")
    }

    private static func skipKeyboardButton(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0x7d170cff, 0x417efd8f, 0xaa40f94d, 0x89c590f9, 0x3fa53905:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
        case 0xd80c25ec, 0xe846b1a0, 0xe15c4370, 0xbcc4af10:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
            _ = try reader.string()
        case 0xe62bc960:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
            _ = try reader.bytes()
        case 0x991399fc:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
            _ = try reader.string()
            if flags & (1 << 1) != 0 { try skipObjectVector(reader: &reader, name: "InlineQueryPeerType") }
        case 0xf51006f9:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
            if flags & 1 != 0 { _ = try reader.string() }
            _ = try reader.string()
            _ = try reader.int32()
        case 0x7a11d782:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            if flags & 1 != 0 { try skipBool(reader: &reader) }
            _ = try reader.string()
        case 0xc0fd5d09:
            let flags = try reader.uint32()
            if flags & (1 << 10) != 0 { try skipKeyboardButtonStyle(reader: &reader) }
            _ = try reader.string()
            _ = try reader.int64()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported KeyboardButton constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipKeyboardButtonStyle(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x4fdd3430 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported KeyboardButtonStyle constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & (1 << 3) != 0 {
            _ = try reader.int64()
        }
    }

    private static func skipInt32Vector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector<int>, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative vector<int> count")
        }
        for _ in 0..<count {
            _ = try reader.int32()
        }
    }

    private static func skipInt64Vector(reader: inout HSTLReader) throws {
        _ = try parseInt64Vector(reader: &reader)
    }

    private static func parseInt64Vector(reader: inout HSTLReader) throws -> [Int64] {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector<long>, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative vector<long> count")
        }
        var values: [Int64] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try reader.int64())
        }
        return values
    }

    private static func skipUserProfilePhoto(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.userProfilePhotoEmpty:
            return
        case HSNativeMTProtoSchema.userProfilePhoto:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & (1 << 1) != 0 {
                _ = try reader.bytes()
            }
            _ = try reader.int32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported UserProfilePhoto constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipUserStatus(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.userStatusEmpty:
            return
        case HSNativeMTProtoSchema.userStatusOnline, HSNativeMTProtoSchema.userStatusOffline:
            _ = try reader.int32()
        case HSNativeMTProtoSchema.userStatusRecently,
            HSNativeMTProtoSchema.userStatusLastWeek,
            HSNativeMTProtoSchema.userStatusLastMonth:
            _ = try reader.uint32()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported UserStatus constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipRestrictionReasons(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected RestrictionReason vector")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative RestrictionReason count")
        }
        for _ in 0..<count {
            let constructor = try reader.uint32()
            guard constructor == HSNativeMTProtoSchema.restrictionReason else {
                throw HSNativeMTProtoError.malformedPacket("unsupported RestrictionReason constructor 0x\(String(constructor, radix: 16))")
            }
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.string()
        }
    }

    private static func skipEmojiStatus(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.emojiStatusEmpty:
            return
        case HSNativeMTProtoSchema.emojiStatus:
            let flags = try reader.uint32()
            _ = try reader.int64()
            if flags & 1 != 0 {
                _ = try reader.int32()
            }
        case HSNativeMTProtoSchema.emojiStatusCollectible:
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.int64()
            _ = try reader.string()
            _ = try reader.string()
            _ = try reader.int64()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            _ = try reader.int32()
            if flags & 1 != 0 {
                _ = try reader.int32()
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported EmojiStatus constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipUsernames(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected Username vector")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative Username count")
        }
        for _ in 0..<count {
            let constructor = try reader.uint32()
            guard constructor == HSNativeMTProtoSchema.username else {
                throw HSNativeMTProtoError.malformedPacket("unsupported Username constructor 0x\(String(constructor, radix: 16))")
            }
            _ = try reader.uint32()
            _ = try reader.string()
        }
    }

    private static func skipPeerColor(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.peerColor else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PeerColor constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 {
            _ = try reader.int32()
        }
        if flags & (1 << 1) != 0 {
            _ = try reader.int64()
        }
    }

    private static func parseStringVector(reader: inout HSTLReader) throws -> [String] {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector<string>, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative vector<string> count")
        }
        var values: [String] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            values.append(try reader.string())
        }
        return values
    }

    private static func skipChannelLocation(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xbfb5ad8b:
            return
        case 0x209b82db:
            try skipGeoPoint(reader: &reader)
            _ = try reader.string()
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChannelLocation constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipInputGroupCall(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xd8aa840f else {
            throw HSNativeMTProtoError.malformedPacket("unsupported InputGroupCall constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int64()
        _ = try reader.int64()
    }

    private static func skipGroupCallParticipant(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xeba636fe else {
            throw HSNativeMTProtoError.malformedPacket("unsupported GroupCallParticipant constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try parsePeer(reader: &reader)
        _ = try reader.int32()
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
        _ = try reader.int32()
        if flags & (1 << 7) != 0 { _ = try reader.int32() }
        if flags & (1 << 11) != 0 { _ = try reader.string() }
        if flags & (1 << 13) != 0 { _ = try reader.int64() }
        if flags & (1 << 6) != 0 { try skipGroupCallParticipantVideo(reader: &reader) }
        if flags & (1 << 14) != 0 { try skipGroupCallParticipantVideo(reader: &reader) }
    }

    private static func skipGroupCallParticipantVideo(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x67753ac8 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported GroupCallParticipantVideo constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.string()
        _ = try reader.int32()
        try skipObjectVector(reader: &reader, name: "GroupCallParticipantVideoSourceGroup")
        _ = try reader.string()
        if flags & 1 != 0 { _ = try reader.int32() }
    }

    private static func skipGroupCallParticipantVideoSourceGroup(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xdcb118b7 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported GroupCallParticipantVideoSourceGroup constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.string()
        try skipInt32Vector(reader: &reader)
    }

    private static func skipExportedChatInvite(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.chatInvitePublicJoinRequests:
            return
        case HSNativeMTProtoSchema.chatInviteExported:
            let flags = try reader.uint32()
            _ = try reader.string()
            _ = try reader.int64()
            _ = try reader.int32()
            if flags & (1 << 4) != 0 { _ = try reader.int32() }
            if flags & (1 << 1) != 0 { _ = try reader.int32() }
            if flags & (1 << 2) != 0 { _ = try reader.int32() }
            if flags & (1 << 3) != 0 { _ = try reader.int32() }
            if flags & (1 << 7) != 0 { _ = try reader.int32() }
            if flags & (1 << 10) != 0 { _ = try reader.int32() }
            if flags & (1 << 8) != 0 { _ = try reader.string() }
            if flags & (1 << 9) != 0 { try skipStarsSubscriptionPricing(reader: &reader) }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ExportedChatInvite constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipStarsSubscriptionPricing(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x5416d58 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported StarsSubscriptionPricing constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int32()
        _ = try reader.int64()
    }

    private static func skipChatReactions(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xeafc32bc:
            return
        case 0x52928bca:
            _ = try reader.uint32()
        case 0x661d4037:
            let vectorConstructor = try reader.uint32()
            guard vectorConstructor == HSNativeMTProtoSchema.vector else {
                throw HSNativeMTProtoError.malformedPacket("expected Reaction vector, got 0x\(String(vectorConstructor, radix: 16))")
            }
            let count = Int(try reader.int32())
            guard count >= 0 else {
                throw HSNativeMTProtoError.malformedPacket("negative Reaction vector count")
            }
            for _ in 0..<count {
                try skipReaction(reader: &reader)
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ChatReactions constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipPeerStories(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x9a35e999 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported PeerStories constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try parsePeer(reader: &reader)
        if flags & 1 != 0 { _ = try reader.int32() }
        try skipObjectVector(reader: &reader, name: "StoryItem")
    }

    private static func skipBotVerification(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0xf93cd45c else {
            throw HSNativeMTProtoError.malformedPacket("unsupported BotVerification constructor 0x\(String(constructor, radix: 16))")
        }
        _ = try reader.int64()
        _ = try reader.int64()
        _ = try reader.string()
    }

    private static func skipProfileTab(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xb98cd696, 0x4d4bd46a, 0x72c64955, 0xab339c00,
            0x9f27d26e, 0xe477092e, 0xd3656499, 0xa2c0f695:
            return
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported ProfileTab constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipForumTopic(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x71701da9 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported ForumTopic constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try reader.string()
        _ = try reader.int32()
        if flags & 1 != 0 { _ = try reader.int64() }
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try reader.int32()
        _ = try parsePeer(reader: &reader)
        try skipPeerNotifySettings(reader: &reader)
        if flags & (1 << 4) != 0 {
            try skipDraftMessage(reader: &reader)
        }
    }

    private static func skipWallPaper(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        switch constructor {
        case 0xa437c3ed:
            _ = try reader.int64()
            let flags = try reader.uint32()
            _ = try reader.int64()
            _ = try reader.string()
            try skipDocument(reader: &reader)
            if flags & (1 << 2) != 0 {
                try skipWallPaperSettings(reader: &reader)
            }
        case 0xe0804116:
            _ = try reader.int64()
            let flags = try reader.uint32()
            if flags & (1 << 2) != 0 {
                try skipWallPaperSettings(reader: &reader)
            }
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported WallPaper constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func skipWallPaperSettings(reader: inout HSTLReader) throws {
        let constructor = try reader.uint32()
        guard constructor == 0x372efcd0 else {
            throw HSNativeMTProtoError.malformedPacket("unsupported WallPaperSettings constructor 0x\(String(constructor, radix: 16))")
        }
        let flags = try reader.uint32()
        if flags & 1 != 0 { _ = try reader.int32() }
        if flags & (1 << 4) != 0 { _ = try reader.int32() }
        if flags & (1 << 5) != 0 { _ = try reader.int32() }
        if flags & (1 << 6) != 0 { _ = try reader.int32() }
        if flags & (1 << 3) != 0 { _ = try reader.int32() }
        if flags & (1 << 4) != 0 { _ = try reader.int32() }
        if flags & (1 << 7) != 0 { _ = try reader.string() }
    }

    private static func skipUnsupportedObject(reader: inout HSTLReader, name: String) throws {
        let constructor = try reader.uint32()
        throw HSNativeMTProtoError.malformedPacket("unsupported \(name) constructor 0x\(String(constructor, radix: 16))")
    }

    private static func parseSentCodeTypeInfo(reader: inout HSTLReader, fallbackEmail: String) throws -> HSNativeSentCodeTypeInfo {
        let constructor = try reader.uint32()
        switch constructor {
        case HSNativeMTProtoSchema.authSentCodeTypeEmailCode:
            let flags = try reader.uint32()
            let emailPattern = try reader.string()
            let length = Int(try reader.int32())
            if flags & (1 << 3) != 0 {
                _ = try reader.int32()
            }
            if flags & (1 << 4) != 0 {
                _ = try reader.int32()
            }
            return HSNativeSentCodeTypeInfo(emailPattern: emailPattern, codeLength: length)
        case HSNativeMTProtoSchema.authSentCodeTypeEmailCodeV2:
            let flags = try reader.uint32()
            let emailPattern = try reader.string()
            let length = Int(try reader.int32())
            if flags & (1 << 2) != 0 {
                _ = try reader.int32()
            }
            return HSNativeSentCodeTypeInfo(emailPattern: emailPattern, codeLength: length)
        case HSNativeMTProtoSchema.authSentCodeTypeApp,
            HSNativeMTProtoSchema.authSentCodeTypeSms,
            HSNativeMTProtoSchema.authSentCodeTypeCall:
            let length = Int(try reader.int32())
            return HSNativeSentCodeTypeInfo(emailPattern: maskedEmail(fallbackEmail), codeLength: length)
        default:
            throw HSNativeMTProtoError.malformedPacket("unsupported auth.SentCodeType constructor 0x\(String(constructor, radix: 16))")
        }
    }

    private static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return email
        }
        let name = String(parts[0])
        let domain = String(parts[1])
        if name.count <= 2 {
            return "\(name.prefix(1))***@\(domain)"
        }
        return "\(name.prefix(2))***@\(domain)"
    }

    private static func displayNameParts(displayName: String, email: String) -> (first: String, last: String) {
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effective = cleaned.isEmpty ? fallbackDisplayName(email: email, fallbackName: email) : cleaned
        let parts = effective.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? effective, parts.count > 1 ? parts[1] : "")
    }

    private static func fallbackDisplayName(email: String, fallbackName: String) -> String {
        let cleaned = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return email.split(separator: "@").first.map(String.init) ?? "HSgram"
    }

    private static func randomInt64() throws -> Int64 {
        let data = try secureRandom(count: 8)
        let value = UInt64(data[0])
            | (UInt64(data[1]) << 8)
            | (UInt64(data[2]) << 16)
            | (UInt64(data[3]) << 24)
            | (UInt64(data[4]) << 32)
            | (UInt64(data[5]) << 40)
            | (UInt64(data[6]) << 48)
            | (UInt64(data[7]) << 56)
        return Int64(bitPattern: value)
    }

    private static func encryptedMessageID(timeDifference: Int32) -> Int64 {
        let adjustedTime = Date().timeIntervalSince1970 + Double(timeDifference)
        let raw = Int64(adjustedTime * 4_294_967_296.0)
        return raw & ~Int64(3)
    }

    private static func consumeMsgIDVector(reader: inout HSTLReader) throws {
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector<long>, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative msg_id vector count")
        }
        for _ in 0..<count {
            _ = try reader.int64()
        }
    }

    private static func validateServerDHMaterial(_ material: HSNativeServerDHMaterial) throws {
        guard material.g > 1, material.g <= Int32(UInt8.max) else {
            throw HSNativeMTProtoError.malformedPacket("unsupported DH generator \(material.g)")
        }
        guard material.dhPrime.count == 256 else {
            throw HSNativeMTProtoError.malformedPacket("expected 2048-bit dh_prime, got \(material.dhPrime.count) bytes")
        }
        guard compareBigEndian(material.gA, Data([1])) > 0,
              compareBigEndian(material.gA, material.dhPrime) < 0 else {
            throw HSNativeMTProtoError.malformedPacket("server g_a is outside the DH prime range")
        }
    }

    private static func parseSetClientDHParamsAnswer(
        response: Data,
        material: HSNativeServerDHMaterial,
        authKey: Data
    ) throws {
        var reader = HSTLReader(data: try parsePlainEnvelope(response))
        let constructor = try reader.uint32()
        let nonce = try reader.raw(count: 16)
        let serverNonce = try reader.raw(count: 16)
        guard nonce == material.probe.nonce, serverNonce == material.probe.serverNonce else {
            throw HSNativeMTProtoError.malformedPacket("set_client_DH_params answer nonce mismatch")
        }

        switch constructor {
        case HSNativeMTProtoSchema.dhGenOk:
            let newNonceHash = try reader.raw(count: 16)
            let expected = try HSNativeMTProtoCrypto.newNonceHash(
                newNonce: material.newNonce,
                authKey: authKey,
                variant: 0x01
            )
            guard newNonceHash == expected else {
                throw HSNativeMTProtoError.malformedPacket("dh_gen_ok new_nonce_hash1 mismatch")
            }
        case HSNativeMTProtoSchema.dhGenRetry:
            _ = try reader.raw(count: 16)
            throw HSNativeMTProtoError.malformedPacket("dh_gen_retry")
        case HSNativeMTProtoSchema.dhGenFail:
            _ = try reader.raw(count: 16)
            throw HSNativeMTProtoError.malformedPacket("dh_gen_fail")
        default:
            throw HSNativeMTProtoError.malformedPacket("expected dh_gen_ok, got 0x\(String(constructor, radix: 16))")
        }
    }

    private static func parseResPQ(response: Data, expectedNonce: Data) throws -> HSNativeMTProtoProbe {
        var envelope = HSTLReader(data: response)
        let authKeyID = try envelope.int64()
        guard authKeyID == 0 else {
            throw HSNativeMTProtoError.malformedPacket("plain handshake auth_key_id is \(authKeyID)")
        }
        _ = try envelope.int64()
        let bodyLength = Int(try envelope.int32())
        let body = try envelope.raw(count: bodyLength)

        var reader = HSTLReader(data: body)
        let constructor = try reader.uint32()
        guard constructor == HSNativeMTProtoSchema.resPq else {
            throw HSNativeMTProtoError.malformedPacket("expected resPQ, got 0x\(String(constructor, radix: 16))")
        }
        let nonce = try reader.raw(count: 16)
        guard nonce == expectedNonce else {
            throw HSNativeMTProtoError.malformedPacket("resPQ nonce mismatch")
        }
        let serverNonce = try reader.raw(count: 16)
        let pq = try reader.bytes()
        let vectorConstructor = try reader.uint32()
        guard vectorConstructor == HSNativeMTProtoSchema.vector else {
            throw HSNativeMTProtoError.malformedPacket("expected vector, got 0x\(String(vectorConstructor, radix: 16))")
        }
        let count = Int(try reader.int32())
        guard count >= 0 else {
            throw HSNativeMTProtoError.malformedPacket("negative fingerprint count")
        }
        var fingerprints: [Int64] = []
        fingerprints.reserveCapacity(count)
        for _ in 0..<count {
            fingerprints.append(try reader.int64())
        }
        return HSNativeMTProtoProbe(
            nonce: nonce,
            serverNonce: serverNonce,
            pq: pq,
            publicKeyFingerprints: fingerprints
        )
    }

    private static func parseServerDHParams(
        response: Data,
        probe: HSNativeMTProtoProbe,
        newNonce: Data,
        p: Data,
        q: Data
    ) throws -> HSNativeServerDHMaterial {
        var bodyReader = HSTLReader(data: try parsePlainEnvelope(response))
        let constructor = try bodyReader.uint32()
        guard constructor != HSNativeMTProtoSchema.serverDHParamsFail else {
            throw HSNativeMTProtoError.malformedPacket("server_DH_params_fail")
        }
        guard constructor == HSNativeMTProtoSchema.serverDHParamsOk else {
            throw HSNativeMTProtoError.malformedPacket("expected server_DH_params_ok, got 0x\(String(constructor, radix: 16))")
        }
        let nonce = try bodyReader.raw(count: 16)
        let serverNonce = try bodyReader.raw(count: 16)
        guard nonce == probe.nonce, serverNonce == probe.serverNonce else {
            throw HSNativeMTProtoError.malformedPacket("server_DH_params nonce mismatch")
        }
        let encryptedAnswer = try bodyReader.bytes()
        let aes = try HSNativeMTProtoCrypto.temporaryAESKeyAndIV(newNonce: newNonce, serverNonce: serverNonce)
        let decryptedAnswer = try HSNativeMTProtoCrypto.aesIGE(
            encryptedAnswer,
            key: aes.key,
            iv: aes.iv,
            operation: CCOperation(kCCDecrypt)
        )
        guard decryptedAnswer.count >= 24 else {
            throw HSNativeMTProtoError.malformedPacket("server_DH_inner_data answer too short")
        }
        var innerReader = HSTLReader(data: decryptedAnswer.subdata(in: 20..<decryptedAnswer.count))
        let innerConstructor = try innerReader.uint32()
        guard innerConstructor == HSNativeMTProtoSchema.serverDHInnerData else {
            throw HSNativeMTProtoError.malformedPacket("expected server_DH_inner_data, got 0x\(String(innerConstructor, radix: 16))")
        }
        let innerNonce = try innerReader.raw(count: 16)
        let innerServerNonce = try innerReader.raw(count: 16)
        guard innerNonce == probe.nonce, innerServerNonce == probe.serverNonce else {
            throw HSNativeMTProtoError.malformedPacket("server_DH_inner_data nonce mismatch")
        }
        let g = try innerReader.int32()
        let dhPrime = try innerReader.bytes()
        let gA = try innerReader.bytes()
        let serverTime = try innerReader.int32()
        return HSNativeServerDHMaterial(
            probe: probe,
            newNonce: newNonce,
            p: p,
            q: q,
            g: g,
            dhPrime: dhPrime,
            gA: gA,
            serverTime: serverTime
        )
    }

    private static func parsePlainEnvelope(_ response: Data) throws -> Data {
        var envelope = HSTLReader(data: response)
        let authKeyID = try envelope.int64()
        guard authKeyID == 0 else {
            throw HSNativeMTProtoError.malformedPacket("plain handshake auth_key_id is \(authKeyID)")
        }
        _ = try envelope.int64()
        let bodyLength = Int(try envelope.int32())
        return try envelope.raw(count: bodyLength)
    }

    private static func selectedFingerprint(from fingerprints: [Int64]) throws -> Int64 {
        guard fingerprints.contains(HSNativeMTProtoCrypto.serverPublicKeyFingerprint) else {
            throw HSNativeMTProtoError.malformedPacket("server public key fingerprint is not bundled in the native client")
        }
        return HSNativeMTProtoCrypto.serverPublicKeyFingerprint
    }

    private static func factorPQ(_ pq: Data) throws -> (p: Data, q: Data) {
        let knownPQ = Data([0x17, 0xed, 0x48, 0x94, 0x1a, 0x08, 0xf9, 0x81])
        guard pq == knownPQ else {
            throw HSNativeMTProtoError.malformedPacket("unsupported pq value \(pq.hexString)")
        }
        return (
            Data([0x49, 0x4c, 0x55, 0x3b]),
            Data([0x53, 0x91, 0x10, 0x73])
        )
    }

    private static func compareBigEndian(_ lhs: Data, _ rhs: Data) -> Int {
        let lhsBytes = trimLeadingZeros(lhs)
        let rhsBytes = trimLeadingZeros(rhs)
        if lhsBytes.count != rhsBytes.count {
            return lhsBytes.count < rhsBytes.count ? -1 : 1
        }
        for (left, right) in zip(lhsBytes, rhsBytes) {
            if left < right {
                return -1
            }
            if left > right {
                return 1
            }
        }
        return 0
    }

    private static func trimLeadingZeros(_ data: Data) -> [UInt8] {
        let bytes = Array(data)
        guard let firstNonZero = bytes.firstIndex(where: { $0 != 0 }) else {
            return [0]
        }
        return Array(bytes[firstNonZero...])
    }

    private static func secureRandom(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw HSNativeMTProtoError.randomBytesFailed(status)
        }
        return data
    }
}

enum HSNativePasswordKDF {
    struct Algorithm: Equatable {
        let salt1: Data
        let salt2: Data
        let g: Int32
        let p: Data
    }

    static func result(password: String, challenge: HSNativePasswordChallenge) throws -> HSNativePasswordKDFResult {
        guard let passwordData = password.data(using: .utf8, allowLossyConversion: true) else {
            throw HSAPIError.server(code: "KDF_ERROR", message: "密码校验参数生成失败。")
        }
        guard challenge.g > 1, challenge.p.count >= 256 else {
            throw HSAPIError.server(code: "PASSWORD_KDF_ALGO_INVALID", message: "服务端返回了无效的密码 KDF 参数。")
        }
        guard isSafeSRPValue(challenge.srpB, modulus: challenge.p) else {
            throw HSAPIError.server(code: "PASSWORD_SRP_B_INVALID", message: "服务端返回了无效的 SRP challenge。")
        }

        let exponentA = try secureRandom(count: challenge.p.count)
        let g = int32BigEndian(challenge.g)
        let paddedG = padded(g, to: challenge.p.count)
        let b = padded(challenge.srpB, to: challenge.p.count)

        let publicA = try HSNativeMTProtoBigInt.modExp(
            base: g,
            exponent: exponentA,
            modulus: challenge.p,
            outputLength: challenge.p.count
        )
        let u = HSNativeMTProtoCrypto.sha256(publicA + b)
        guard !u.allSatisfy({ $0 == 0 }) else {
            throw HSAPIError.server(code: "PASSWORD_SRP_U_INVALID", message: "密码校验参数生成失败。")
        }

        let pbkdfInner = HSNativeMTProtoCrypto.sha256(
            challenge.salt2
                + HSNativeMTProtoCrypto.sha256(challenge.salt1 + passwordData + challenge.salt1)
                + challenge.salt2
        )
        let pbkdf = try pbkdf2SHA512(password: pbkdfInner, salt: challenge.salt1, rounds: 100_000, outputLength: 64)
        let x = HSNativeMTProtoCrypto.sha256(challenge.salt2 + pbkdf + challenge.salt2)

        let gx = try HSNativeMTProtoBigInt.modExp(
            base: g,
            exponent: x,
            modulus: challenge.p,
            outputLength: challenge.p.count
        )
        let k = HSNativeMTProtoCrypto.sha256(challenge.p + paddedG)
        let kgx = try HSNativeMTProtoBigInt.modMultiply(k, gx, modulus: challenge.p, outputLength: challenge.p.count)
        let s1 = try HSNativeMTProtoBigInt.modSubtract(b, kgx, modulus: challenge.p, outputLength: challenge.p.count)
        guard isSafeSRPValue(s1, modulus: challenge.p) else {
            throw HSAPIError.server(code: "PASSWORD_SRP_S_INVALID", message: "密码校验参数生成失败。")
        }

        let ux = HSNativeMTProtoBigInt.multiply(u, x)
        let s2 = HSNativeMTProtoBigInt.add(exponentA, ux)
        let s = try HSNativeMTProtoBigInt.modExp(
            base: s1,
            exponent: s2,
            modulus: challenge.p,
            outputLength: challenge.p.count
        )

        let key = HSNativeMTProtoCrypto.sha256(padded(s, to: challenge.p.count))
        let pHash = HSNativeMTProtoCrypto.sha256(challenge.p)
        let gHash = HSNativeMTProtoCrypto.sha256(paddedG)
        let proofPrefix = xor(pHash, gHash)
        let proof = HSNativeMTProtoCrypto.sha256(
            proofPrefix
                + HSNativeMTProtoCrypto.sha256(challenge.salt1)
                + HSNativeMTProtoCrypto.sha256(challenge.salt2)
                + publicA
                + b
                + key
        )
        return HSNativePasswordKDFResult(id: challenge.srpID, a: publicA, m1: proof)
    }

    static func updateHash(password: String, algorithm: Algorithm) throws -> HSNativePasswordUpdateKDFResult {
        guard let passwordData = password.data(using: .utf8, allowLossyConversion: true) else {
            throw HSAPIError.server(code: "KDF_ERROR", message: "密码设置参数生成失败。")
        }
        guard algorithm.g > 1, algorithm.p.count >= 256 else {
            throw HSAPIError.server(code: "PASSWORD_KDF_ALGO_INVALID", message: "服务端返回了无效的密码 KDF 参数。")
        }

        var salt1 = algorithm.salt1
        salt1.append(try secureRandom(count: 32))
        let updatedAlgorithm = Algorithm(salt1: salt1, salt2: algorithm.salt2, g: algorithm.g, p: algorithm.p)
        let g = int32BigEndian(updatedAlgorithm.g)
        let pbkdfInner = HSNativeMTProtoCrypto.sha256(
            updatedAlgorithm.salt2
                + HSNativeMTProtoCrypto.sha256(updatedAlgorithm.salt1 + passwordData + updatedAlgorithm.salt1)
                + updatedAlgorithm.salt2
        )
        let pbkdf = try pbkdf2SHA512(password: pbkdfInner, salt: updatedAlgorithm.salt1, rounds: 100_000, outputLength: 64)
        let x = HSNativeMTProtoCrypto.sha256(updatedAlgorithm.salt2 + pbkdf + updatedAlgorithm.salt2)
        let passwordHash = try HSNativeMTProtoBigInt.modExp(
            base: g,
            exponent: x,
            modulus: updatedAlgorithm.p,
            outputLength: updatedAlgorithm.p.count
        )
        return HSNativePasswordUpdateKDFResult(algorithm: updatedAlgorithm, passwordHash: passwordHash)
    }

    private static func secureRandom(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw HSNativeMTProtoError.randomBytesFailed(status)
        }
        return data
    }

    private static func pbkdf2SHA512(password: Data, salt: Data, rounds: UInt32, outputLength: Int) throws -> Data {
        var output = Data(count: outputLength)
        let status = output.withUnsafeMutableBytes { outputBuffer in
            password.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        rounds,
                        outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                        outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw HSAPIError.server(code: "KDF_ERROR", message: "密码校验参数生成失败。")
        }
        return output
    }

    private static func int32BigEndian(_ value: Int32) -> Data {
        var bigEndian = UInt32(bitPattern: value).bigEndian
        return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
    }

    private static func padded(_ data: Data, to count: Int) -> Data {
        guard data.count < count else {
            return data
        }
        return Data(repeating: 0, count: count - data.count) + data
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        let count = max(lhs.count, rhs.count)
        var left = padded(lhs, to: count)
        let right = padded(rhs, to: count)
        for index in 0..<count {
            left[index] ^= right[index]
        }
        return left
    }

    private static func isSafeSRPValue(_ value: Data, modulus: Data) -> Bool {
        compare(value, Data([1])) > 0 && compare(value, decrement(modulus)) < 0
    }

    private static func decrement(_ value: Data) -> Data {
        var bytes = Array(value)
        for index in stride(from: bytes.count - 1, through: 0, by: -1) {
            if bytes[index] > 0 {
                bytes[index] -= 1
                break
            }
            bytes[index] = 0xff
        }
        return Data(bytes)
    }

    private static func compare(_ lhs: Data, _ rhs: Data) -> Int {
        let left = trimLeadingZeros(lhs)
        let right = trimLeadingZeros(rhs)
        if left.count != right.count {
            return left.count < right.count ? -1 : 1
        }
        for (leftByte, rightByte) in zip(left, right) {
            if leftByte < rightByte {
                return -1
            }
            if leftByte > rightByte {
                return 1
            }
        }
        return 0
    }

    private static func trimLeadingZeros(_ data: Data) -> [UInt8] {
        let bytes = Array(data)
        guard let firstNonZero = bytes.firstIndex(where: { $0 != 0 }) else {
            return [0]
        }
        return Array(bytes[firstNonZero...])
    }
}

struct HSTLWriter {
    private(set) var data = Data()

    mutating func constructor(_ value: UInt32) {
        uint32(value)
    }

    mutating func int32(_ value: Int32) {
        var littleEndian = value.littleEndian
        data.appendBytes(of: &littleEndian)
    }

    mutating func uint32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        data.appendBytes(of: &littleEndian)
    }

    mutating func int64(_ value: Int64) {
        var littleEndian = value.littleEndian
        data.appendBytes(of: &littleEndian)
    }

    mutating func double(_ value: Double) {
        var littleEndian = value.bitPattern.littleEndian
        data.appendBytes(of: &littleEndian)
    }

    mutating func string(_ value: String) {
        bytes(Data(value.utf8))
    }

    mutating func bytes(_ value: Data) {
        let count = value.count
        if count < 254 {
            data.append(UInt8(count))
        } else {
            data.append(254)
            data.append(UInt8(count & 0xff))
            data.append(UInt8((count >> 8) & 0xff))
            data.append(UInt8((count >> 16) & 0xff))
        }
        data.append(value)
        while data.count % 4 != 0 {
            data.append(0)
        }
    }

    mutating func raw(_ value: Data) {
        data.append(value)
    }
}

struct HSTLReader {
    private let data: Data
    private var offset: Int = 0

    mutating func rewindUInt32() {
        offset = max(0, offset - 4)
    }

    init(data: Data) {
        self.data = data
    }

    mutating func int32() throws -> Int32 {
        Int32(bitPattern: try uint32())
    }

    mutating func uint32() throws -> UInt32 {
        let bytes = try raw(count: 4)
        return UInt32(bytes[0])
            | (UInt32(bytes[1]) << 8)
            | (UInt32(bytes[2]) << 16)
            | (UInt32(bytes[3]) << 24)
    }

    mutating func int64() throws -> Int64 {
        let bytes = try raw(count: 8)
        let value = UInt64(bytes[0])
            | (UInt64(bytes[1]) << 8)
            | (UInt64(bytes[2]) << 16)
            | (UInt64(bytes[3]) << 24)
            | (UInt64(bytes[4]) << 32)
            | (UInt64(bytes[5]) << 40)
            | (UInt64(bytes[6]) << 48)
            | (UInt64(bytes[7]) << 56)
        return Int64(bitPattern: value)
    }

    mutating func double() throws -> Double {
        let bytes = try raw(count: 8)
        let value = UInt64(bytes[0])
            | (UInt64(bytes[1]) << 8)
            | (UInt64(bytes[2]) << 16)
            | (UInt64(bytes[3]) << 24)
            | (UInt64(bytes[4]) << 32)
            | (UInt64(bytes[5]) << 40)
            | (UInt64(bytes[6]) << 48)
            | (UInt64(bytes[7]) << 56)
        return Double(bitPattern: value)
    }

    mutating func bytes() throws -> Data {
        let first = try raw(count: 1)[0]
        let count: Int
        let headerLength: Int
        if first == 254 {
            let lengthBytes = try raw(count: 3)
            count = Int(lengthBytes[0]) | (Int(lengthBytes[1]) << 8) | (Int(lengthBytes[2]) << 16)
            headerLength = 4
        } else {
            count = Int(first)
            headerLength = 1
        }
        let value = try raw(count: count)
        let padding = (4 - ((headerLength + count) % 4)) % 4
        if padding > 0 {
            _ = try raw(count: padding)
        }
        return value
    }

    mutating func string() throws -> String {
        let value = try bytes()
        guard let string = String(data: value, encoding: .utf8) else {
            throw HSNativeMTProtoError.malformedPacket("invalid UTF-8 TL string")
        }
        return string
    }

    mutating func raw(count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else {
            throw HSNativeMTProtoError.malformedPacket("wanted \(count) bytes at offset \(offset), packet has \(data.count)")
        }
        let value = data.subdata(in: offset..<(offset + count))
        offset += count
        return value
    }

    mutating func remainingData() -> Data {
        let value = data.subdata(in: offset..<data.count)
        offset = data.count
        return value
    }
}

private extension HSStickerSet {
    func withThumbDocument(_ documentID: Int64?) -> HSStickerSet {
        guard let documentID, documentID != 0 else {
            return self
        }
        return HSStickerSet(
            id: id,
            title: title,
            shortName: shortName,
            count: count,
            installed: installed,
            featured: featured,
            official: official,
            premium: premium,
            animated: animated,
            videos: videos,
            thumbDocument: documentID
        )
    }
}

private final class HSNativeMTProtoIntermediateTransport {
    private let configuration: HSNativeMTProtoConfiguration
    private let queue = DispatchQueue(label: "cloud.hsgram.native.mtproto.intermediate")
    private let endpointQueue = DispatchQueue(label: "cloud.hsgram.native.mtproto.endpoint")
    private var preferredEndpoint: HSNativeMTProtoEndpoint?

    init(configuration: HSNativeMTProtoConfiguration) {
        self.configuration = configuration
    }

    func roundTrip(plainBody: Data, timeout: TimeInterval = 8) async throws -> Data {
        try await withSession(timeout: timeout) { session in
            try await session.sendPlainBody(plainBody)
        }
    }

    func withSession<T>(
        timeout: TimeInterval = 8,
        _ operation: @escaping (HSNativeMTProtoIntermediateSession) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        let endpoints = orderedEndpoints()
        for endpoint in endpoints {
            let session = HSNativeMTProtoIntermediateSession(configuration: configuration, endpoint: endpoint)
            do {
                try await session.connect(timeout: timeout)
                rememberPreferredEndpoint(endpoint)
                defer {
                    session.close()
                }
                return try await operation(session)
            } catch {
                session.close()
                guard shouldTryNextEndpoint(after: error), endpoint != endpoints.last else {
                    throw error
                }
                lastError = error
            }
        }
        throw lastError ?? HSNativeMTProtoError.connectionFailed("No HSgram MTProto endpoints are configured.")
    }

    private func orderedEndpoints() -> [HSNativeMTProtoEndpoint] {
        let endpoints = configuration.endpoints
        guard let preferred = endpointQueue.sync(execute: { preferredEndpoint }),
              endpoints.contains(preferred) else {
            return endpoints
        }
        return [preferred] + endpoints.filter { $0 != preferred }
    }

    private func rememberPreferredEndpoint(_ endpoint: HSNativeMTProtoEndpoint) {
        endpointQueue.sync {
            preferredEndpoint = endpoint
        }
    }

    private func shouldTryNextEndpoint(after error: Error) -> Bool {
        guard let mtProtoError = error as? HSNativeMTProtoError else {
            return false
        }
        switch mtProtoError {
        case .connectionFailed, .timedOut:
            return true
        case .malformedPacket, .randomBytesFailed, .serverDHParamsPending, .encryptedTransportPending:
            return false
        }
    }
}

final class HSNativeMTProtoIntermediateSession {
    private let configuration: HSNativeMTProtoConfiguration
    private let endpoint: HSNativeMTProtoEndpoint
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "cloud.hsgram.native.mtproto.intermediate.session")
    private var buffer = Data()
    private var didSendMarker = false

    init(configuration: HSNativeMTProtoConfiguration, endpoint: HSNativeMTProtoEndpoint) {
        self.configuration = configuration
        self.endpoint = endpoint
        self.connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(rawValue: endpoint.port)!,
            using: .tcp
        )
    }

    func connect(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            func finish(_ result: Result<Void, Error>) {
                queue.async {
                    guard !completed else {
                        return
                    }
                    completed = true
                    continuation.resume(with: result)
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(HSNativeMTProtoError.timedOut))
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .failed(let error):
                    finish(.failure(HSNativeMTProtoError.connectionFailed(error.localizedDescription)))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func close() {
        connection.cancel()
    }

    func sendPlainBody(_ plainBody: Data, timeout: TimeInterval = 8) async throws -> Data {
        let msgID = Self.messageID()
        var envelope = Data()
        var authKeyID = Int64(0).littleEndian
        envelope.appendBytes(of: &authKeyID)
        var messageID = msgID.littleEndian
        envelope.appendBytes(of: &messageID)
        var bodyLength = Int32(plainBody.count).littleEndian
        envelope.appendBytes(of: &bodyLength)
        envelope.append(plainBody)

        return try await sendRawPayload(envelope, timeout: timeout)
    }

    func sendRawPayload(_ payload: Data, timeout: TimeInterval = 8) async throws -> Data {
        try await sendIntermediatePayload(payload, timeout: timeout)
        return try await receiveRawPayload(timeout: timeout)
    }

    func receiveRawPayload(timeout: TimeInterval = 8) async throws -> Data {
        let lengthData = try await readExact(count: 4, timeout: timeout)
        let length = try Self.responseLength(from: lengthData)
        return try await readExact(count: length, timeout: timeout)
    }

    private func sendIntermediatePayload(_ payload: Data, timeout: TimeInterval) async throws {
        var packet = Data()
        if !didSendMarker {
            var transportMarker = UInt32(0xeeeeeeee).littleEndian
            packet.appendBytes(of: &transportMarker)
            didSendMarker = true
        }
        var payloadLength = Int32(payload.count).littleEndian
        packet.appendBytes(of: &payloadLength)
        packet.append(payload)

        try await send(packet: packet, timeout: timeout)
    }

    private func send(packet: Data, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false

            func finish(_ result: Result<Void, Error>) {
                queue.async {
                    guard !completed else {
                        return
                    }
                    completed = true
                    continuation.resume(with: result)
                }
            }

            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(HSNativeMTProtoError.timedOut))
            }

            connection.send(content: packet, completion: .contentProcessed { error in
                if let error {
                    finish(.failure(HSNativeMTProtoError.connectionFailed(error.localizedDescription)))
                    return
                }
                finish(.success(()))
            })
        }
    }

    private func readExact(count: Int, timeout: TimeInterval) async throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        while buffer.count < count {
            let remaining = max(0.1, deadline.timeIntervalSinceNow)
            buffer.append(try await receiveChunk(timeout: remaining))
        }
        let value = buffer.prefixData(count)
        buffer.removeFirst(count)
        return value
    }

    private func receiveChunk(timeout: TimeInterval) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var completed = false
            func finish(_ result: Result<Data, Error>) {
                queue.async {
                    guard !completed else {
                        return
                    }
                    completed = true
                    continuation.resume(with: result)
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(HSNativeMTProtoError.timedOut))
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error {
                    finish(.failure(HSNativeMTProtoError.connectionFailed(error.localizedDescription)))
                    return
                }
                if let data, !data.isEmpty {
                    finish(.success(data))
                    return
                }
                if isComplete {
                    finish(.failure(HSNativeMTProtoError.malformedPacket("connection closed before a full intermediate packet arrived")))
                    return
                }
                finish(.failure(HSNativeMTProtoError.malformedPacket("empty TCP receive")))
            }
        }
    }

    private static func responseLength(from lengthData: Data) throws -> Int {
        guard lengthData.count == 4 else {
            throw HSNativeMTProtoError.malformedPacket("intermediate length prefix must be 4 bytes")
        }
        let length = UInt32(lengthData[0])
            | (UInt32(lengthData[1]) << 8)
            | (UInt32(lengthData[2]) << 16)
            | (UInt32(lengthData[3]) << 24)
        guard length <= 1024 * 1024 else {
            throw HSNativeMTProtoError.malformedPacket("intermediate packet too large: \(length)")
        }
        return Int(length)
    }

    private static func messageID() -> Int64 {
        let raw = Int64(Date().timeIntervalSince1970 * 4_294_967_296.0)
        return raw & ~Int64(3)
    }
}

private extension Data {
    mutating func appendBytes<T>(of value: inout T) {
        Swift.withUnsafeBytes(of: &value) { bytes in
            append(contentsOf: bytes)
        }
    }

    func prefixData(_ count: Int) -> Data {
        Data(prefix(count))
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
