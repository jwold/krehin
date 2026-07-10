// Drafts action script: first line is the title, remaining lines are Markdown.
const credential = Credential.create(
    "Krehin Micropub",
    "Enter the Krehin publishing endpoint and access token."
);
credential.addURLField("endpoint", "Micropub endpoint");
credential.addPasswordField("token", "Access token");

if (!credential.authorize()) {
    context.cancel("Krehin credentials were not provided.");
} else {
    const text = draft.content.trim();
    if (!text) {
        context.fail("The draft is empty.");
    } else {
        const lines = text.split(/\r?\n/);
        const title = lines.shift().replace(/^#\s+/, "").trim();
        const content = lines.join("\n").trim();
        const response = HTTP.create().request({
            url: credential.getValue("endpoint"),
            method: "POST",
            encoding: "form",
            headers: {
                Authorization: `Bearer ${credential.getValue("token")}`
            },
            data: {
                h: "entry",
                name: title,
                content: content
            }
        });

        if (response.statusCode === 201) {
            draft.addTag("published");
            draft.update();
        } else {
            context.fail(`Krehin returned ${response.statusCode}: ${response.responseText || response.error}`);
        }
    }
}
