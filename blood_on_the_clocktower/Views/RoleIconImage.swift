import SwiftUI

struct RoleIconImage: View {
    let role: RoleTemplate?

    private var assetNameCandidates: [String] {
        guard let role else { return [] }
        return [
            "role_\(role.id)",
            "role-\(role.id)"
        ]
    }

    var body: some View {
        if let role {
            if !role.id.isEmpty, let assetName = assetNameCandidates.first {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: role.icon)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
        }
    }
}

// Drop role icons here:
// blood_on_the_clocktower/blood_on_the_clocktower/Assets.xcassets/RoleIcons/role_<roleId>.imageset
// where <roleId> equals the role id, e.g. role_washerwoman.
