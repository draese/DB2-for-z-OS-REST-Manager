// DB2 for z/OS REST Manager by Oliver Draese
//
// To the extent possible under law, the person who associated CC0 with
// DB2 for z/OS REST Manager has waived all copyright and related or neighboring
// rights to DB2 for z/OS REST Manager.
//
// You should have received a copy of the CC0 legalcode along with this
// work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import Cocoa

/// View Controller for the bind options view.
///
/// The bind options are displayed in an extra sheet that is laid over the
/// main window. The view, being part of the main story board, uses an 
/// instance of this class as view controller. This controller displays
/// the available bind options as drop down box values within a table
/// view.
class OptionsViewController: NSViewController {
    /// The options that can be chosen by the user (input)
    var selectableOptions: CreateOptions?
    
    /// currently selected values/options
    fileprivate var _currentSelections = Dictionary<String,Int>()
    
    /// Computed property for the currently selected options.
    ///
    /// While the `selectableOptions` property contains a cached
    /// list of all available options, this property represents 
    /// only the options that were changed by the user. There are
    /// only entries in the dictionary for options where the user
    /// selected a value other than "Default". The dictionary uses
    /// the option name as key and the selected option as value.
    var selectedOptions: Dictionary<String,String> {
        set(newValue) {
            if let allOptions = selectableOptions?.bindMultipleSelect {
                // clear out old settings
                // The _currentSelections maps the option name to the
                // drop down list selection index where index zero is
                // the "Default" entry.
                _currentSelections.removeAll()
                
                for entry in newValue {
                    for scanIdx in 0 ..< allOptions.count {
                        let option = allOptions[scanIdx]
                        
                        if option.name == entry.key {
                            for valueIdx in 0 ..< option.values.count {
                                if option.values[valueIdx] == entry.value {
                                    // use +1 on index because 0 is default
                                    _currentSelections[entry.key] = valueIdx + 1
                                    break
                                }
                            }
                            
                            break
                        }
                    }
                }
            }
            else {
                fatalError("Can't set selectedOptions before selectableObtions")
            }
        }
        
        get {
            var ret = Dictionary<String,String>()
            
            // generate a dictionary with all non-default values
            if let allOptions = selectableOptions?.bindMultipleSelect {
                for entry in _currentSelections {
                    if entry.value > 0 {
                        for option in allOptions {
                            if option.name == entry.key {
                                ret[option.name] = option.values[entry.value-1]
                                break
                            }
                        }
                    }
                }
            }
            
            return ret
        }
    }
    

    /// Code to be executed if the bind options dialog is closed
    var completionHandler: ((OptionsViewController)->Void)?
    
    /// Action handler for the cancel button.
    ///
    /// The handler just closes the view. The completion handler is
    /// not triggered, neither are any options stored.
    ///
    /// - Parameter sender: The cancel button (ignored)
    @IBAction func cancelPressed(_ sender: Any) {
        self.view.window?.close()
    }
    
    /// Action handler for the "Apply" button.
    ///
    /// This handler triggers the completion handler (which will extract
    /// the selected bind options) and then closes the view/dialog.
    ///
    /// - Parameter sender: The apply button (ignored)
    @IBAction func applyPressed(_ sender: Any) {
        if let handler = self.completionHandler {
            handler( self )
        }
        
        self.view.window?.close()
    }
}

// MARK: - Delegate and DataSource of the TableView with the bind options
extension OptionsViewController: NSTableViewDataSource, NSTableViewDelegate {
    /// Enumerations of the column IDs for the options table
    private enum Col {
        static let Name  = "nameColumn"
        static let Value = "valueColumn"
    }
    
    /// Returns the total number of rows for the options table.
    ///
    /// This implementation just has to return the number of selectable
    /// options when being invoked by the table view.
    ///
    /// - Parameter tableView: The options table view (ignored)
    /// - Returns: The amount of bind options, known to this view
    func numberOfRows(in tableView: NSTableView) -> Int {
        var ret = 0
        
        if let so = selectableOptions {
            ret = so.bindMultipleSelect?.count ?? 0
        }
        
        return ret
    }
    
    /// Returns the content of a cell of the options table view.
    ///
    /// This implementation returns the cell value as `String` instance.
    ///
    /// - Parameters:
    ///   - tableView: The options table view (ignored0
    ///   - tableColumn: Column for which to get the content
    ///   - row: Row of the table = option index
    /// - Returns: The content of the specified table as `String`
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        var ret: Any?
        
        // do we actually have selectable options?
        if let optionArray = selectableOptions?.bindMultipleSelect {
            if optionArray.count > row {
                let option = optionArray[row]
                
                // handle based on requested column
                if let id = tableColumn?.identifier {
                    switch( id ) {
                    case Col.Name:
                        ret = option.name
                    case Col.Value:
                        // if we don't have any selection value or the selection
                        // value is zero, we return the current "Default" option
                        if let currentSelection = _currentSelections[option.name ] {
                            if currentSelection == 0 {
                                ret = "Default"
                            }
                            else {
                                ret = option.values[currentSelection - 1]
                            }
                        }
                        else {
                            _currentSelections[option.name] = 0
                            ret = "Default"
                        }
                        
                    default:
                        // should never happen as we only have these two columns
                        ret = "N/A"
                    }
                }
            }
        }
        
        return ret
    }
    
    /// Setter for new column values.
    ///
    /// Within the options table, only the right side of the table is editable.
    /// The left side is used to displaay the "label" of the bind option. The
    /// right side is used for drop down lists. If the drop down selection is
    /// changed, this method is called by the table view to provide the new
    /// value.
    ///
    /// - Parameters:
    ///   - tableView: The options table view (ignored)
    ///   - object: The new selected drop down value (as `String`)
    ///   - tableColumn: Should always be the right column (ignored)
    ///   - row: Row of the table = index of the selectable option
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        if let optionArray = selectableOptions?.bindMultipleSelect {
            if optionArray.count > row {
                if let id = tableColumn?.identifier {
                    // care about the right (value) column only
                    if id == Col.Value {
                        if let newVal = object as? String {
                            let option = optionArray[row]
                            
                            // store the index of the option (0=Default)
                            if let idx = option.values.index(of: newVal) {
                                _currentSelections[option.name] = idx + 1
                            }
                            else {
                                _currentSelections[option.name] = 0
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Delivers a tooltip for the options table view.
    ///
    /// The table view is calling this method to get a tool tip text
    /// for a specific table cell. This implementation returns the
    /// option description as it was received from DB2.
    ///
    /// - Parameters:
    ///   - tableView: The options table view (ignored)
    ///   - cell: The cell for which to query the tool tip (ignored)
    ///   - rect: Position of the table cell (ignored)
    ///   - tableColumn: Identifies the table column (ignored)
    ///   - row: Table view row = options index
    ///   - mouseLocation: Mouse position (ignored)
    /// - Returns: The option description of the specified row
    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        var ret = ""
        
        if let optionArray = selectableOptions?.bindMultipleSelect {
            if optionArray.count > row {
                ret = optionArray[row].desctiprion
            }
        }
        
        return ret
    }
    
    /// Called to prepare a specific table cell before it is rendered.
    ///
    /// This method is called from the table view for each cell that is about
    /// to be rendered. This implementation uses the call to manipulate the 
    /// content of the drop down box, adding the values that are available
    /// for the current option.
    ///
    /// - Parameters:
    ///   - tableView: The options table view (ignored)
    ///   - cell: The cell to be rendered
    ///   - tableColumn: Identifies the column, the cell belongs to
    ///   - row: Gives the row index (option index) of the cell
    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        if let optionArray = selectableOptions?.bindMultipleSelect {
            if optionArray.count > row {
                if let id = tableColumn?.identifier {
                    let option = optionArray[row]
                    
                    // we only have to adjust the content for the values column
                    if id == Col.Value {
                        if let comboCell = cell as? NSComboBoxCell {
                            // repopulate the content of the drop boxes
                            comboCell.removeAllItems()
                            comboCell.addItem(withObjectValue: "Default" )
                            comboCell.addItems(withObjectValues: option.values )
                            
                            // select the right combo box item
                            if let selected = _currentSelections[option.name] {
                                comboCell.selectItem( at: selected )
                            }
                            else {
                                comboCell.selectItem(at: 0)
                            }
                        }
                    }
                }
            }
        }
    }
}
