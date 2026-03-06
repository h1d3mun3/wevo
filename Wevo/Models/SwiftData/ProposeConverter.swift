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
            payloadHash: propose.payloadHash,
            spaceID: spaceID,
            signatures: signatureModels,
            createdAt: propose.createdAt ?? Date()
        )
    }
    
    /// ProposeSwiftDataからPropose構造体へ変換
    static func toEntity(from model: ProposeSwiftData) -> Propose {
        let signatureEntities = model.signatures.map { signatureModel in
            SignatureConverter.toEntity(from: signatureModel)
        }
        
        return Propose(
            id: model.id,
            payloadHash: model.payloadHash,
            signatures: signatureEntities,
            createdAt: model.createdAt
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
        model.payloadHash = propose.payloadHash
        model.updatedAt = Date()
        
        // 既存のSignatureをクリアして新しいものを追加
        model.signatures.removeAll()
        let newSignatures = propose.signatures.map { signature in
            SignatureConverter.toModel(from: signature)
        }
        model.signatures.append(contentsOf: newSignatures)
    }
}

/// Signature構造体とSignatureSwiftDataの相互変換を行う
struct SignatureConverter {
    
    /// Signature構造体からSignatureSwiftDataへ変換
    static func toModel(from signature: Signature) -> SignatureSwiftData {
        return SignatureSwiftData(
            id: signature.id,
            publicKey: signature.publicKey,
            signatureData: signature.signatureData,
            createdAt: signature.createdAt ?? Date()
        )
    }
    
    /// SignatureSwiftDataからSignature構造体へ変換
    static func toEntity(from model: SignatureSwiftData) -> Signature {
        return Signature(
            id: model.id,
            publicKey: model.publicKey,
            signatureData: model.signatureData,
            createdAt: model.createdAt
        )
    }
}
