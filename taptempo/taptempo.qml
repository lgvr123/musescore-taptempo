import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.1

/**********************
/* Parking B - Tap Tempo
/* ChangeLog:
/* 	- 1.0.0: Initial releasee
/* 	- 1.1.0: Retrieve the tempo value from tempo text (and not only the tempo multiplier)
/* 	- 1.2.0: empty placeholder
/* 	- 1.2.0: Qt.quit issue
/* 	- 1.2.1: Port to MS4.0
/**********************************************/
MuseScore {
    menuPath: "Plugins." + pluginName
    description: "Tap a rythm for adding or changing a tempo marker."
    version: "1.2.1"
    readonly property var pluginName: "Tap tempo"

    pluginType: "dialog"

    id: mainWindow

    // requiresScore: true

    width: 400
    height: 200

    Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
            mainWindow.title = pluginName ;
            mainWindow.thumbnailName = "logoTapTempo.png";
        }
    }

    readonly property int averageOn: 5
    property var lastclicks: []
    property var tempo: -1
	property var tempomult: 1

    property var tempoElement
	
	property var curSegment
	
	property var multipliers : [
		//mult is a tempo-multiplier compared to a crotchet      
		{text: '\uECA2',               mult: 4     , sym: '<sym>metNoteWhole</sym>' }, // 1/1
		{text: '\uECA3 \uECB7',        mult: 3     , sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym>' }, // 1/2.
		{text: '\uECA3',               mult: 2     , sym: '<sym>metNoteHalfUp</sym>' }, // 1/2
		{text: '\uECA5 \uECB7 \uECB7', mult: 1.75  , sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' }, // 1/4..
		{text: '\uECA5 \uECB7',        mult: 1.5   , sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym>' }, // 1/4.
		{text: '\uECA5',               mult: 1     , sym: '<sym>metNoteQuarterUp</sym>' }, // 1/4
		{text: '\uECA7 \uECB7 \uECB7', mult: 0.875 , sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' }, // 1/8..
		{text: '\uECA7 \uECB7',        mult: 0.75  , sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym>' }, // 1/8.
		{text: '\uECA7',               mult: 0.5   , sym: '<sym>metNote8thUp</sym>' }, // 1/8
		{text: '\uECA9 \uECB7 \uECB7', mult: 0.4375, sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' }, //1/16..
		{text: '\uECA9 \uECB7',        mult: 0.375 , sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym>' }, //1/16.
		{text: '\uECA9',               mult: 0.25  , sym: '<sym>metNote16thUp</sym>' }, //1/16
		]
	

	onRun: {
	    var selection = curScore.selection;
	    if (selection != null) {
	        var element = selection.elements[0];
	        if (element) {
	            console.log("first is " + element.userName());
	            if (element.type == Element.TEMPO_TEXT) {
	                tempoElement = element;
	            } else {
	                // chord/note
	                curSegment = element.parent;
	                while (curSegment.type !== Element.SEGMENT) {
	                    curSegment = curSegment.parent;
	                }
	                tempoElement = findExistingTempoElement(curSegment);
	            }

	            if (tempoElement != null) {
	                console.log("found text: " + tempoElement.text);
					var res= findBeatBaseFromMarking(tempoElement);
					tempomult=res.multiplier;
					tempo=res.tempo;
	                console.log("found mult: " + tempomult);

	            } else {
	                console.log("Couldn't find a tempo text");
	            }
	        }
	    }

	    debugO("--tempo", tempo);

	    if (!tempoElement && !curSegment) {
	        warningDialog.text = "Invalid selection. A Tempo text or a valid segment must be selected";
	      //  warningDialog.quitOnClose = true;
	        warningDialog.open();
	        return;
	    }

	}

	ColumnLayout {
	    id: layout
	    // padding: 10
	    anchors.margins: 10
	    anchors.fill: parent

	    RowLayout {
	        spacing: 5
	        Layout.alignment: Qt.AlignHCenter
	        Layout.fillHeight: true

	        ComboBox {
	            id: lstMult
	            model: multipliers

	            textRole: "text"
	            valueRole: "mult"

	            onActivated: {
	                // loopMode = currentValue;
	                tempomult = model[currentIndex][valueRole];
	                console.log(tempomult);
	            }

	            Binding on currentIndex {
	                value: multipliers.map(function (e) {
	                    return e[lstMult.valueRole]
	                }).indexOf(tempomult);
	            }

	            implicitHeight: 60
	            implicitWidth: 90

	            font.family: 'MScore Text'
	            font.pointSize: 15

	            delegate: ItemDelegate {
	                contentItem: Text {
	                    text: modelData[lstMult.textRole]
	                    verticalAlignment: Text.AlignVCenter
	                    font: lstMult.font
	                }
	                highlighted: multipliers.highlightedIndex === index

	            }

	        }
			SpinBox {
			    id: txtTempo
			    Layout.preferredHeight: 60
			    from: 0
			    to: 360
			    stepSize: 1

			    editable: true

			    font.pointSize: 13
			    textFromValue: function (value) {
			        var text = (value > 0) ? value : "";
			        debugO("textFromValue", text);
			        return text;
			    }

			    valueFromText: function (text) {
			        var val = (text === "") ? -1 : parseInt(text);
					if (isNaN(val)) val=-1; 
			        debugO("valueFromText", val);
			        return val;
			    }

			    onValueChanged: tempo = value // triggers a Binding loop but without it manual modifications are not reported to the temp variable

				Binding on value {
					value: tempo
				}

			    validator: IntValidator {
			        locale: txtTempo.locale.name
			        bottom: 0
			        top: txtTempo.to
			    }

			}
			Button {
				id: btnTap
				text: "Tap!"

				font.pointSize: 15

				background: Rectangle {
					implicitWidth: 60
					implicitHeight: 60
					color: btnTap.down ? "#17a81a" : "#21be2b"
					radius: 4
				}

				onClicked: {
					if (lastclicks.length == averageOn)
						lastclicks.shift(); // removing oldest one
					lastclicks.push(new Date());
					if (lastclicks.length >= 2) {
						var avg = 0;
						for (var i = 1; i < lastclicks.length; i++) {
							avg += (lastclicks[i] - lastclicks[i - 1]);
						}
						console.log("total diffs: " + avg);
						avg = avg / (lastclicks.length - 1);
						console.log("avg diffs: " + avg);
						tempo = Math.round(60 * 1000 / avg);
						debugO("--tempo", tempo);

					} else {
						tempo = -1;
					}

				}
			}

		}
		RowLayout {
			Layout.fillWidth: true
			spacing: 10

			Button {
				id: btnReset
				text: "Reset"
				onClicked: {
					lastclicks = [];
					tempo = -1;
				}
			}

			Item {
				Layout.fillWidth: true
			}

			DialogButtonBox {
				//Layout.fillWidth: true
				Layout.alignment: Qt.AlignRight

				background.opacity: 0 // hide default white background

				standardButtons: DialogButtonBox.Cancel
				Button {
					text: tempoElement ? "Change" : "Insert"
					DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
				}

				onAccepted: {
					//... do the stuff ...
					console.log("mult: " + tempomult);
					console.log("tempo: " + tempo);
					var settings=multipliers.find(function(e) { return e.mult=== tempomult});
					
					if (settings==undefined || tempo<=0) {
						warningDialog.text="Invalid tempo. Must be >0";
						warningDialog.open();
						return;
					}
					
					var tempotext=settings.sym+' = '+tempo;
					console.log("text: " + tempotext);
					curScore.startCmd();
					if (tempoElement!=null) {
						tempoElement.text=tempotext;
					} else {
						tempoElement=newElement(Element.TEMPO_TEXT);
						tempoElement.text=tempotext;
						var cursor = curScore.newCursor();
						cursor.rewindToTick(curSegment.tick);
						cursor.add(tempoElement);
					}
					//changing of tempo can only happen after being added to the segment
					tempoElement.tempo = tempo * tempomult;
					tempoElement.tempoFollowText = true; //allows for manual fiddling by the user afterwards
					curScore.endCmd();
                    mainWindow.parent.Window.window.close(); //Qt.quit()
				}
				onRejected: 
                    mainWindow.parent.Window.window.close(); //Qt.quit()

			}

		}
	}

	// === From TempoChanges plugin =========================================================
	function findExistingTempoElement(segment) { //look in reverse order, there might be multiple TEMPO_TEXTs attached
	    // in that case MuseScore uses the last one in the list
	    for (var i = segment.annotations.length; i-- > 0; ) {
	        if (segment.annotations[i].type === Element.TEMPO_TEXT) {
	            return (segment.annotations[i]);
	        }
	    }
	    return undefined; //invalid - no tempo text found
	}

	/// Analyses tempo marking text to attempt to discover the base beat being used
	/// If a beat is detected, returns the following structure:
	/// @returns { multiplier: float, tempo: int } where
	/// multiplier = -1 if beat is not detected or not present in our beatBaseList
	/// tempo = 0 if tempo is not detected
	function findBeatBaseFromMarking(tempoMarking) {
	    // First look for metronome marking symbols
		var foundTempoText=tempoMarking.text.replace('<sym>space</sym>', '');
	    var foundMetronomeSymbols = foundTempoText.match(/(<sym>met.*<\/sym>)+/g);

	    // strip html tags and split around '='
		var data = foundTempoText.replace(/<.*?>/g,'').split('=');
		var tempo=parseInt(data[1]);
		if (isNaN(tempo)) tempo=0;


	    if (foundMetronomeSymbols !== null) {
	        // Locate the index in our dropdown matching the found beatString
	        for (var i = multipliers.length; --i >= 0; ) {
	            if (multipliers[i].sym == foundMetronomeSymbols[0]) {
	                // Found this marking in the dropdown at metronomeMarkIndex
	                return {multiplier: multipliers[i].mult, tempo: tempo};
	            }
	        }
	    } else {
	        // Metronome marking symbols are substituted with their character entity if the text was edited
	        // UTF-16 range [\uECA0 - \uECB6] (double whole - 1024th)
	        for (var beatString, charidx = 0; charidx < foundTempoText.length; charidx++) {
	            beatString = foundTempoText[charidx];
	            if ((beatString >= "\uECA2") && (beatString <= "\uECA9")) {
	                // Found base tempo - continue looking for augmentation dots
	                while (++charidx < foundTempoText.length) {
	                    if (foundTempoText[charidx] == "\uECB7") {
	                        beatString += " \uECB7";
	                    } else if (foundTempoText[charidx] != ' ') {
	                        break; // No longer augmentation dots or spaces
	                    }
	                }
	                // Locate the index in our dropdown matching the found beatString

	                for (var i = multipliers.length; --i >= 0; ) {
	                    if (multipliers[i].text == beatString) {
	                        // Found this marking in the dropdown at metronomeMarkIndex
							return {multiplier: multipliers[i].mult, tempo: tempo};
	                    }
	                }

	                break; // Done processing base tempo
	            }
	        }
	    }
	    return {multiplier: -1, tempo: tempo};
	}

	// ============================================================

	// === TEMPLATE =========================================================
	function getSelection() {
		var chords = SelHelper.getChordsRestsFromCursor();

		if (chords && (chords.length > 0)) {
			console.log("CHORDS FOUND FROM CURSOR");
		} else {
			chords = SelHelper.getChordsRestsFromSelection();
			if (chords && (chords.length > 0)) {
				console.log("CHORDS FOUND FROM SELECTION");
			} else
				chords = [];
		}

		return chords;
	}

    MessageDialog {
        id: warningDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Ok
        title: 'Warning' + (subtitle ? (" - " + subtitle) : "")
        property var subtitle
        property var quitOnClose: false;
		
        text: "--"
        onAccepted: {
            subtitle = undefined;
			if (quitOnClose) Qt.quit();
        }
    }

	function debugO(label, element, excludes) {

		if (typeof element === 'undefined') {
			console.log(label + ": undefined");
		} else if (element === null) {
			console.log(label + ": null");

		} else if (Array.isArray(element)) {
			for (var i = 0; i < element.length; i++) {
				debugO(label + "-" + i, element[i], excludes);
			}

		} else if (typeof element === 'object') {

			var kys = Object.keys(element);
			for (var i = 0; i < kys.length; i++) {
				if (!excludes || excludes.indexOf(kys[i]) == -1) {
					debugO(label + ": " + kys[i], element[kys[i]], excludes);
				}
			}
		} else {
			console.log(label + ": " + element);
		}
	}
}
