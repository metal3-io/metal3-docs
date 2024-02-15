async function getMatch(match) {
    // Check if the match is already in the session storage
    let version = sessionStorage.getItem(`${match[0]}`);
    let version_tag;

    if (version) {
        // If it is, parse it and use it
        version_tag = JSON.parse(version);
    } else {
        const repo = match[1];
        const stable = match[3];

        version_tag = await getReleaseLink(repo, stable);
        sessionStorage.setItem(match[0], JSON.stringify(version_tag));
        console.log("Fetching version tag from GitHub");
    }

    return version_tag;
}

// Function to fetch the latest release tag name from a GitHub repository
async function getReleaseLink(repo, stable="stable") {
    const response = await fetch(`${repo}/releases`);
    let releases = await response.json();
    
    switch (stable) {
        case "any":
            break;
        case "stable":
            releases = releases.filter(release => !release.prerelease);
            break;
        case "prerelease":
            releases = releases.filter(release => release.prerelease);
            break;
    }

    return releases[0].tag_name;
    
}

async function replacePlaceholders() {
    // Regular expression to match the placeholders
    // and parse the api url to get the tag name
    const regex = /\{releaselink:repo:(.*?)(:stable:(.*?))?\}/g;
    html = document.body.innerHTML;
    const matches = [...html.matchAll(regex)];


    // Loop through the matches and replace the placeholders
    // with the tag name in the HTML
    for (const match of matches) {
        const tagName = await getMatch(match);
        if (tagName === undefined) {
            continue;
        }
        html = html.replace(match[0], tagName);
    }

    document.body.innerHTML = html;
}
replacePlaceholders();
