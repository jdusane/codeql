/**
 * Provides Java specific classes and predicates for definining flow summaries.
 */

private import java
private import DataFlowDispatch
private import DataFlowPrivate
private import DataFlowUtil
private import FlowSummaryImpl::Private
private import FlowSummaryImpl::Public
private import semmle.code.java.dataflow.ExternalFlow

private module FlowSummaries {
  private import semmle.code.java.dataflow.FlowSummary as F
}

/** Gets the parameter position of the instance parameter. */
int instanceParameterPosition() { result = -1 }

/** Gets the synthesized summary data-flow node for the given values. */
Node summaryNode(SummarizedCallable c, SummaryNodeState state) { result = getSummaryNode(c, state) }

/** Gets the synthesized data-flow call for `receiver`. */
SummaryCall summaryDataFlowCall(Node receiver) { result.getReceiver() = receiver }

/** Gets the type of content `c`. */
DataFlowType getContentType(Content c) { result = c.getType() }

/** Gets the return type of kind `rk` for callable `c`. */
DataFlowType getReturnType(SummarizedCallable c, ReturnKind rk) {
  result = getErasedRepr(c.asCallable().getReturnType()) and
  exists(rk)
}

/**
 * Gets the type of the `i`th parameter in a synthesized call that targets a
 * callback of type `t`.
 */
DataFlowType getCallbackParameterType(DataFlowType t, int i) {
  result = getErasedRepr(t.(FunctionalInterface).getRunMethod().getParameterType(i))
  or
  result = getErasedRepr(t.(FunctionalInterface)) and i = -1
}

/**
 * Gets the return type of kind `rk` in a synthesized call that targets a
 * callback of type `t`.
 */
DataFlowType getCallbackReturnType(DataFlowType t, ReturnKind rk) {
  result = getErasedRepr(t.(FunctionalInterface).getRunMethod().getReturnType()) and
  exists(rk)
}

/**
 * Holds if an external flow summary exists for `c` with input specification
 * `input`, output specification `output`, and kind `kind`.
 */
predicate summaryElement(DataFlowCallable c, string input, string output, string kind) {
  exists(
    string namespace, string type, boolean subtypes, string name, string signature, string ext
  |
    summaryModel(namespace, type, subtypes, name, signature, ext, input, output, kind) and
    c.asCallable() = interpretElement(namespace, type, subtypes, name, signature, ext)
  )
}

/** Gets the summary component for specification component `c`, if any. */
bindingset[c]
SummaryComponent interpretComponentSpecific(AccessPathToken c) {
  exists(Content content | parseContent(c, content) and result = SummaryComponent::content(content))
}

/** Gets the summary component for specification component `c`, if any. */
private string getContentSpecificCsv(Content c) {
  exists(Field f, string package, string className, string fieldName |
    f = c.(FieldContent).getField() and
    f.hasQualifiedName(package, className, fieldName) and
    result = "Field[" + package + "." + className + "." + fieldName + "]"
  )
  or
  exists(SyntheticField f |
    f = c.(SyntheticFieldContent).getField() and result = "SyntheticField[" + f + "]"
  )
  or
  c instanceof ArrayContent and result = "ArrayElement"
  or
  c instanceof CollectionContent and result = "Element"
  or
  c instanceof MapKeyContent and result = "MapKey"
  or
  c instanceof MapValueContent and result = "MapValue"
}

/** Gets the textual representation of the content in the format used for flow summaries. */
string getComponentSpecificCsv(SummaryComponent sc) {
  exists(Content c | sc = TContentSummaryComponent(c) and result = getContentSpecificCsv(c))
}

/** Gets the textual representation of a parameter position in the format used for flow summaries. */
string getParameterPositionCsv(ParameterPosition pos) { result = pos.toString() }

/** Gets the textual representation of an argument position in the format used for flow summaries. */
string getArgumentPositionCsv(ArgumentPosition pos) { result = pos.toString() }

/** Holds if input specification component `c` needs a reference. */
predicate inputNeedsReferenceSpecific(string c) { none() }

/** Holds if output specification component `c` needs a reference. */
predicate outputNeedsReferenceSpecific(string c) { none() }

class SourceOrSinkElement = Top;

/**
 * Holds if an external source specification exists for `e` with output specification
 * `output` and kind `kind`.
 */
predicate sourceElement(SourceOrSinkElement e, string output, string kind) {
  exists(
    string namespace, string type, boolean subtypes, string name, string signature, string ext
  |
    sourceModel(namespace, type, subtypes, name, signature, ext, output, kind) and
    e = interpretElement(namespace, type, subtypes, name, signature, ext)
  )
}

/**
 * Holds if an external sink specification exists for `e` with input specification
 * `input` and kind `kind`.
 */
predicate sinkElement(SourceOrSinkElement e, string input, string kind) {
  exists(
    string namespace, string type, boolean subtypes, string name, string signature, string ext
  |
    sinkModel(namespace, type, subtypes, name, signature, ext, input, kind) and
    e = interpretElement(namespace, type, subtypes, name, signature, ext)
  )
}

/** Gets the return kind corresponding to specification `"ReturnValue"`. */
ReturnKind getReturnValueKind() { any() }

private newtype TInterpretNode =
  TElement(SourceOrSinkElement n) or
  TNode(Node n)

/** An entity used to interpret a source/sink specification. */
class InterpretNode extends TInterpretNode {
  /** Gets the element that this node corresponds to, if any. */
  SourceOrSinkElement asElement() { this = TElement(result) }

  /** Gets the data-flow node that this node corresponds to, if any. */
  Node asNode() { this = TNode(result) }

  /** Gets the call that this node corresponds to, if any. */
  DataFlowCall asCall() { result.asCall() = this.asElement() }

  /** Gets the callable that this node corresponds to, if any. */
  DataFlowCallable asCallable() { result.asCallable() = this.asElement() }

  /** Gets the target of this call, if any. */
  Callable getCallTarget() { result = this.asCall().asCall().getCallee().getSourceDeclaration() }

  /** Gets a textual representation of this node. */
  string toString() {
    result = this.asElement().toString()
    or
    result = this.asNode().toString()
  }

  /** Gets the location of this node. */
  Location getLocation() {
    result = this.asElement().getLocation()
    or
    result = this.asNode().getLocation()
  }
}

/** Provides additional sink specification logic required for annotations. */
pragma[inline]
predicate interpretOutputSpecific(string c, InterpretNode mid, InterpretNode node) {
  exists(Node n, Top ast |
    n = node.asNode() and
    ast = mid.asElement()
  |
    (c = "Parameter" or c = "") and
    node.asNode().asParameter() = mid.asElement()
    or
    c = "" and
    n.asExpr().(FieldRead).getField() = ast
  )
}

/** Provides additional source specification logic required for annotations. */
pragma[inline]
predicate interpretInputSpecific(string c, InterpretNode mid, InterpretNode n) {
  exists(FieldWrite fw |
    c = "" and
    fw.getField() = mid.asElement() and
    n.asNode().asExpr() = fw.getRHS()
  )
}

/** Gets the argument position obtained by parsing `X` in `Parameter[X]`. */
bindingset[s]
ArgumentPosition parseParamBody(string s) { result = AccessPath::parseInt(s) }

/** Gets the parameter position obtained by parsing `X` in `Argument[X]`. */
bindingset[s]
ParameterPosition parseArgBody(string s) { result = AccessPath::parseInt(s) }
