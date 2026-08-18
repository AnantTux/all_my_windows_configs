ListTitles() {
    allTitles := WinGetList()
    output := ""
    for i, winID in allTitles {
        output .= WinGetTitle(winID) . "`n"
    }
    MsgBox output
}
ListTitles()