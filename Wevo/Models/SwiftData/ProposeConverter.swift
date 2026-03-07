//
//  ProposeConverter.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import Foundation

/// Propose構造体とProposeSwiftDataの相互変換を行う
struct ProposeConverter {
    
    /// Propose構造体からProposeSwiftDataへ変換
    static func toModel(from propose: Propose, spaceID: UUID) -> ProposeSwiftData {
        let signatureModels = propose.signatures.map { signature in
            SignatureConverter.toModel(from: signature)
        }
        
        return ProposeSwiftData(
            id: propose.id,
            message: propose.message,
            payloadHash: propose.payloadHash,
            spaceID: spaceID,
            signatures: signatureModels,
            createdAt: propose.createdAt,
            updatedAt: propose.updatedAt
        )
    }
    
    /// ProposeSwiftDataからPropose構造体へ変換
    static func toEntity(from model: ProposeSwiftData) -> Propose {
        let signatureEntities = (model.signatures ?? []).map { signatureModel in
            SignatureConverter.toEntity(from: signatureModel)
        }
        
        return Propose(
            id: model.id,
            message: model.message,
            signatures: signatureEntities,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
    
    /// 複数のProposeSwiftDataを変換
    static func toEntities(from models: [ProposeSwiftData]) -> [Propose] {
        return models.map { model in
            toEntity(from: model)
        }
    }
    
    /// ProposeSwiftDataを既存のPropose構造体で更新
    static func updateModel(_ model: ProposeSwiftData, with propose: Propose) {
        model.message = propose.message
        model.payloadHash = propose.payloadHash
        model.updatedAt = Date()
        
        // 既存の署名のIDセットを取得
        let existingSignatureIDs = Set((model.signatures ?? []).map { $0.id })

        // 新しい署名のみを追加（既存の署名は維持）
        let newSignatures = propose.signatures.compactMap { signature -> SignatureSwiftData? in
            // 既にモデルに存在する署名はスキップ
            guard !existingSignatureIDs.contains(signature.id) else { return nil }
            return SignatureConverter.toModel(from: signature)
        }
        
        // 新しい署名のみを追加
        model.signatures?.append(contentsOf: newSignatures)

        print("📝 Updated ProposeSwiftData: existing=\(existingSignatureIDs.count), new=\(newSignatures.count), total=\((model.signatures ?? []).count)")
    }
}

/// Signature構造体とSignatureSwiftDataの相互変換を行う
struct SignatureConverter {
    
    /// Signature構造体からSignatureSwiftDataへ変換
    static func toModel(from signature: Signature) -> SignatureSwiftData {
        return SignatureSwiftData(
            id: signature.id,
            publicKey: signature.publicKey,
            signatureData: signature.signature,
            createdAt: signature.createdAt
        )
    }
    
    /// SignatureSwiftDataからSignature構造体へ変換
    static func toEntity(from model: SignatureSwiftData) -> Signature {
        return Signature(
            id: model.id,
            publicKey: model.publicKey,
            signature: model.signatureData,
            createdAt: model.createdAt
        )
    }
}

