# Motivation

The motivation behind this initiative is to provide easy to use presentation templates for Metal3 projects, which can then be imported and built-upon to create presentation for Meetups, Conferences or any other platforms. This can serve as a supplement to existing documentation for new users, and also help spread the project by helping presenters save time and focus on their content.

# Framework

We are using the [Revealjs](https://revealjs.com/) framework to create the presentation. To contribute a presentation please create a directory, at the `meta3-docs/docs/presentations` path, with your files associated with the presentation, for example :-
```
ls metal3-docs/docs/presentations/test-presentation
test-image1.png  test-image2-capi.png test-presentation.html test-presentation.md
```

To use this with revealjs, follow these steps (for more details refer [here](https://revealjs.com/installation/#full-setup)) :
```
# Clone revealjs repository
cd ${to_your_presentation_directory} && git clone https://github.com/hakimel/reveal.js.git

# Optional steps
cd reveal.js && npm install
npm start
```

Now you can simply edit the presentation html, markdown files to build upon the presentation

For exporting the presentation in pdf format, you can use [decktape](https://github.com/astefanutti/decktape#install), for example :
```
decktape reveal test-presentation.html test_deck.pdf
```

Exporing to .odp or .pptx formats is not supported but this [issue](https://github.com/hakimel/reveal.js/issues/1702) might help.
