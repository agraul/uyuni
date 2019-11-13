/* eslint-disable */
import * as React from 'react';
import {Utils, Formulas} from 'utils/functions';
import {generateFormulaComponent, generateFormulaComponentForId} from './FormulaComponentGenerator';
import HelpIcon from 'components/HelpIcon';
import "./formula-form.css";
import SectionToggle from './SectionToggle';

const EditGroupSubtype = Formulas.EditGroupSubtype;
const getEditGroupSubtype = Formulas.getEditGroupSubtype;
const deepCopy = Utils.deepCopy;
// circular dependencies are bad

/*
 * Base class for edit-group.
 * Based on the edit-group data, the corresponing shape of component is used.
 */
class EditGroup extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            visible: true
        };
        ["handleAddItem", "handleRemoveItem", "isDisabled", "setVisible", "isVisible"].forEach(method => this[method] = this[method].bind(this));
    }

    isDisabled() {
        const formScope = this.props.formulaForm.props.scope;
        const elementScope = this.props.element.$scope;
        return elementScope === "readonly" || (formScope !== elementScope && elementScope !== "system") || this.props.disabled;
    }

    handleAddItem(event) {
        if (this.props.element.$maxItems <= this.props.value.length || this.isDisabled())
            return;

        let newValueProps = this.props.value;
        let newValue = deepCopy(this.props.element.$newItemValue);

        newValueProps.push(newValue);

        this.props.formulaForm.handleChange({
            id: this.props.id,
            value: newValueProps
        });
    }

    handleRemoveItem(index) {
        if (this.props.element.$minItems >= this.props.value.length || this.isDisabled())
            return;

        this.props.value.splice(index, 1);
        this.props.formulaForm.handleChange({
            id: this.props.id,
            value: this.props.value
        });
    }

    isVisible(index) {
        return this.state.visible;
    }

    setVisible(index, visible) { // index not needed here
        this.setState({visible: visible});
    }

    render() {
        const element = this.props.element;
        const subType = getEditGroupSubtype(element);

        let Component;
        if (subType === EditGroupSubtype.PRIMITIVE_LIST) {
            Component = EditPrimitiveGroup;
        } else if (subType === EditGroupSubtype.PRIMITIVE_DICTIONARY) {
            Component = EditPrimitiveDictionaryGroup;
        } else {
            Component = EditDictionaryGroup;
        }

        return (
            <div id={this.props.id} className={this.isVisible() ? "formula-content-section-open" : "formula-content-section-closed"}>
                <div className="group-heading">
                    <SectionToggle setVisible={this.setVisible} isVisible={this.isVisible}>
                        <h4>{this.props.element.$name}</h4>
                    </SectionToggle>
                    <i className="fa fa-plus"
                        id={this.props.id + '#add_item'}
                        title={this.props.element.$maxItems <= this.props.value.length ? "Max number of items reached" : "Add Item"}
                        onClick={this.handleAddItem}
                        disabled={(this.props.element.$maxItems <= this.props.value.length) || this.props.disabled}>
                    </i>
                </div>
                <div>
                    { this.state.visible ?
                    <React.Fragment>
                        { "$help" in this.props.element ? <p>{this.props.element.$help}</p> : null }
                        <Component
                            handleRemoveItem={this.handleRemoveItem}
                            isDisabled={this.isDisabled()}
                            id={this.props.id}
                            key={this.props.key}
                            element={this.props.element}
                            value={this.props.value}
                        formulaForm={this.props.formulaForm}/>
                    </React.Fragment> : null }
                </div>
            </div>);
    }
}

/*
 * Used for rendering edit-groups in the form of "list of primitive types",
 * to be rendered as a list of simple form elements in the UI.
 */
class EditPrimitiveGroup extends React.Component {

    constructor(props) {
        super(props);
        ["simpleWrapper"].forEach(method => this[method] = this[method].bind(this));

    };

    simpleWrapper(name, required, element, help = null) {
        return (
            <React.Fragment>
                <div className="col-lg-3">
                    {element}
                </div>
                {required ? <span className="required-form-field" style={{float: "left", paddingRight: "10px"}}>*</span> : null}
                <HelpIcon text={this.props.element["$help"]}/>
        </React.Fragment>);
    }

    render() {
        let elements = [];
        for (let i in this.props.value) {
            if (i === "$meta") {
                continue;
            }
            let id = this.props.id + "#" + i;
            elements.push(
                <div className="form-group" id={id} key={id}>
                    {generateFormulaComponentForId(
                        this.props.element.$prototype,
                        this.props.value[i],
                        this.props.formulaForm,
                        id,
                        this.simpleWrapper,
                        this.props.isDisabled)}
                    <RemoveButton
                        minItems={this.props.element.$minItems}
                        currentLength={this.props.value.length}
                        handleRemoveItem={() => this.props.handleRemoveItem(i)} />
                </div>
            );
        }
        return (<div id={this.props.id + "$elements"}>{elements}</div>);
    }
}


/*
 * Used for rendering edit-groups in the form of "dictionary of primitive types",
 * to be rendered as a list of [key, value] in the UI.
 */
class EditPrimitiveDictionaryGroup extends React.Component {

    constructor(props) {
        super(props);
    };

    pairElementWrapper(elementName) {
        return (name, required, element) => (
            <div key={elementName}>
                <label className="col-lg-1 control-label">
                    {elementName}
                    {required ? <span className="required-form-field"> *</span> : null}
                    :
                </label>
                <div className="col-lg-3">
                    {element}
                </div>
            </div>);
    }

    render() {
        let elements = [];

        for(let i in this.props.value) {
            if (i === "$meta") {
                continue;
            }
            let id = this.props.id + "#" + i;
            elements.push(
                <div className="form-group" id={id} key={id}>
                    {generateFormulaComponentForId(
                        this.props.element.$prototype.$key,
                        this.props.value[i][0],
                        this.props.formulaForm,
                        id + "#0",
                        this.pairElementWrapper(this.props.element.$prototype.$key.$name),
                        this.props.isDisabled
                        )}
                    {generateFormulaComponentForId(
                        this.props.element.$prototype,
                        this.props.value[i][1],
                        this.props.formulaForm,
                        id + "#1",
                        this.pairElementWrapper(get(this.props.element.$prototype.$name, "Value")),
                        this.props.isDisabled
                        )}
                    <RemoveButton
                        minItems={this.props.element.$minItems}
                        currentLength={this.props.value.length}
                        handleRemoveItem={() => this.props.handleRemoveItem(i)} />
                </div>
            );
        }
        return (<div id={this.props.id + "$elements"}>{elements}</div>);
    }
}


class RemoveButton extends React.Component {
    constructor(props) {
        super(props);
    }

    render() {
        return (<button className="btn btn-default"
            type="button"
            title={this.props.minItems >= this.props.currentLength ? "Min number of items reached" : "Remove item"}
            onClick={() => this.props.handleRemoveItem()}
            disabled={this.props.minItems >= this.props.currentLength}>
            <i className="fa fa-minus" /> Remove
        </button>);
    }
}


/*
 * Used for rendering edit-groups that are backed up list of dictionaries
 * to be rendered as a list of key-value groups in the UI.
 */
class EditDictionaryGroup extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            visibility: new Map()
        };
        ["isVisible", "setVisible"].forEach(method => this[method] = this[method].bind(this));
    }

    wrapKeyGroup(element_name, required, innerHTML) {
        return (
            <div className="form-group" key={element_name}>
                <label className="col-lg-3 control-label">
                    {element_name}
                    <span className="required-form-field"> *</span>
                    :
                </label>
                <div className="col-lg-6" >
                    {innerHTML}
                </div>
                <i className="fa fa-question-circle" title={t("This field is used as a 'key' identifier in the resulting pillar data.")}></i>
            </div>
        );
    }

    generateItemName(item_index) {
        let name = this.props.element.$itemName;
        name = name.replace(/\${i}/g, parseInt(item_index, 10) + 1);
        name = name.replace(/\${.*}/g, txt => get(this.props.value[item_index][txt.substring(2, txt.length - 1)], txt));
        return name;
    }

    isVisible(index) {
        return this.state.visibility.get(index) === undefined ||
            this.state.visibility.get(index) === true;
    }

    setVisible(index, visible) {
        const { visibility } = this.state;
        visibility.set(index, visible);
        this.setState({ visibility });
    }

    render() {
        let elements = [];
        for (let i in this.props.value) {
            if (i === "$meta") {
                continue;
            }
            let id = this.props.id + "#" + i;

            let item_elements = [];
            for (var element_name in this.props.element.$prototype) {
                if (element_name.startsWith("$") && element_name !== "$key") continue;
                item_elements.push(generateFormulaComponent(
                    this.props.element.$prototype[element_name],
                    this.props.value[i][element_name],
                    this.props.formulaForm,
                    id,
                    element_name === "$key" ? this.wrapKeyGroup : undefined,
                    this.props.isDisabled
                 ));
            }

            elements.push(
                <div id={id} key={id} className={this.isVisible(i) ? "formula-content-section-open" : "formula-content-section-closed"}>
                    <div className="group-heading">
                        <SectionToggle index={i} setVisible={this.setVisible} isVisible={this.isVisible}>
                            <h4>{this.generateItemName(i)}</h4>
                        </SectionToggle>
                        <i className="fa fa-minus"
                            onClick={() => this.props.handleRemoveItem(i)}
                            title={this.props.element.$minItems >= this.props.value.length ? "Min number of items reached" : "Remove item"}
                            disabled={this.props.element.$minItems >= this.props.value.length || this.props.isDisabled} />
                    </div>
                    <div>
                        {this.state.visibility.get(i) === undefined || this.state.visibility.get(i) === true ? item_elements : null }
                    </div>
                </div>
            );
        }
        return (<div id={this.props.id + "$elements"}>{elements}</div>);
    }
}

function get(value, default_value) {
    if (value === undefined)
        return default_value;
    return value;
}

export default EditGroup;
