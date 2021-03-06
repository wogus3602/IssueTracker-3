//
//  CreateIssueInteractor.swift
//  IssueTracker
//
//  Created by 송민관 on 2020/11/08.
//

import Foundation

protocol CreateIssueDataStore {
    var createdIssue: Issue? { get set }
}

protocol CreateIssueBusinessLogic {
    func uploadIssue(title: String, comment: String, milestoneID: Int?, labelids: [Int])
    func uploadLabel(id: Int, labelIDs: [Int?])
    func uploadAssignee(id: Int, assigneeIDs: [Int?])
    func editIssue(id: Int, title: String, comment: String, milestoneID: Int?, completion: @escaping () -> Void)
}

final class CreateIssueInteractor: CreateIssueDataStore {
    let networkService: NetworkServiceProvider = NetworkService()
    var createdIssue: Issue?
    private var issueID: Int?
    
    private func createIssue(id: Int = 0, title: String, comment: String, milestoneID: Int?, labelids: [Int]? = nil) -> Issue {
        guard let milestoneID = milestoneID else {
            return Issue(id: id, title: title, body: comment, labelids: labelids)
        }
        return Issue(id: id, title: title, body: comment, milestoneID: .integer(milestoneID), labelids: labelids)
    }
}

extension CreateIssueInteractor: CreateIssueBusinessLogic {
    func uploadIssue(title: String, comment: String, milestoneID: Int?, labelids: [Int]) {
        createdIssue = createIssue(title: title, comment: comment, milestoneID: milestoneID, labelids: labelids)
        
        guard let data = createdIssue?.encoded() else {
            debugPrint("uploadIssue encoding error")
            return
        }
        networkService.request(apiConfiguration: CreateIssueEndPoint.upload(data)) { result in
            switch result {
            case .failure(let error):
                debugPrint(error)
                return
            case .success(let data):
                guard let decodedData: String = try? data.decoded() else {
                    debugPrint("upload response decode 실패")
                    return
                }
                debugPrint(decodedData)
                return
            }
        }
    }

    func editIssue(id: Int, title: String, comment: String, milestoneID: Int?, completion: @escaping () -> Void) {
        createdIssue = createIssue(id: id, title: title, comment: comment, milestoneID: milestoneID)
        guard let data = createdIssue?.encoded() else {
            debugPrint("createIssue encoding error")
            return
        }

        networkService.request(apiConfiguration: CreateIssueEndPoint.edit(data)) { result in
            switch result {
            case .failure(let error):
                debugPrint(error)
                return
            case .success:
                completion()
                return
            }
        }
    }

    func uploadLabel(id: Int, labelIDs: [Int?]) {
        let label = labelIDs.compactMap({$0})
        let model = UploadLabelModel(tags: label)
        let encoded = model.encoded()
        networkService.request(apiConfiguration: CreateIssueEndPoint.label(encoded, id)) { result in
            switch result {
            case .failure(let error):
                debugPrint(error)
                // Error 처리
                return
            case .success:
                return
            }
        }
    }

    func uploadAssignee(id: Int, assigneeIDs: [Int?]) {
        let label = assigneeIDs.compactMap({$0})
        let model = UploadAssigneeModel(assignees: label)
        let encoded = model.encoded()
        networkService.request(apiConfiguration: CreateIssueEndPoint.assignee(encoded, id)) { result in
            switch result {
            case .failure(let error):
                debugPrint(error)
                // Error 처리
                return
            case .success:
                return
            }
        }
    }
}

struct UploadLabelModel: Codable {
    let tags: [Int]
}

struct UploadAssigneeModel: Codable {
    let assignees: [Int]
}
