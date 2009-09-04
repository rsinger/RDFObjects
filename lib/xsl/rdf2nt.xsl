<?xml version="1.0" ?>

<!-- RDFT 2.0 by Jason Diamond <http://injektilo.org/>
 |
 |   Transforms RDF/XML into N-Triples. See <http://www.w3.org/TR/rdf-syntax-grammar>
 |   and <http://www.w3.org/TR/rdf-testcases/#ntriples> for more information.
 |
 |   This version requires that all RDF attributes be qualified!
 |
 |   Specify the base-uri parameter as the URI for the source document in
 |   order to resolve relative URIs (currently just rdf:ID attributes).
 |
 |   Import this transform and override the output-statement and
 |   output-literal-statement named templates to create your own output
 |   formats.
 |
 |   TODO:
 |
 |     * Reification.
 |     * Correct URI resolution.
 |     * Fix bugs.
 |     * Track RDF Working Draft changes.
 |     * More helpful error checking.
 |     * Documentation.
 |     * More?
 |
 |   HISTORY:
 |
 |     2002-01-02:
 |       * First Draft.
 +-->

<xsl:transform version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
>
  <xsl:output method="text" encoding="utf-8" />

  <xsl:param name="base-uri" />

  <xsl:template match="text()" />
  <xsl:template match="text()" mode="node" />
  <xsl:template match="text()" mode="property" />

  <xsl:template match="rdf:RDF">
    <xsl:apply-templates mode="node" />
  </xsl:template>

  <!-- node elements -->

  <xsl:template match="*" mode="node">
    <xsl:param name="subject" />
    <xsl:param name="predicate" />

    <xsl:variable name="id">
      <xsl:choose>
        <xsl:when test="@rdf:ID">
          <xsl:value-of select="concat($base-uri, '#', @rdf:ID)" />
        </xsl:when>
        <xsl:when test="@rdf:about">
          <xsl:value-of select="@rdf:about" />
        </xsl:when>
        <xsl:when test="@ID">
          <xsl:message terminate="yes">error: encountered unqualified ID attribute!</xsl:message>
        </xsl:when>
        <xsl:when test="@about">
          <xsl:message terminate="yes">error: encountered unqualified about attribute!</xsl:message>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('_:', generate-id())" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:if test="not(self::rdf:Description)">
      <xsl:call-template name="output-type-statement">
        <xsl:with-param name="subject" select="$id" />
        <xsl:with-param name="object">
          <xsl:call-template name="check-li" />
        </xsl:with-param>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$subject and $predicate">
      <xsl:call-template name="output-statement">
        <xsl:with-param name="subject" select="$subject" />
        <xsl:with-param name="predicate" select="$predicate" />
        <xsl:with-param name="object" select="$id" />
      </xsl:call-template>
    </xsl:if>

    <xsl:apply-templates select="@*" mode="property">
      <xsl:with-param name="subject" select="$id" />
    </xsl:apply-templates>

    <xsl:apply-templates mode="property">
      <xsl:with-param name="subject" select="$id" />
    </xsl:apply-templates>

  </xsl:template>

  <!-- property elements -->

  <xsl:template match="*[*]" mode="property">
    <xsl:param name="subject" />

    <xsl:variable name="predicate">
      <xsl:call-template name="check-li" />
    </xsl:variable>

    <xsl:apply-templates mode="node">
      <xsl:with-param name="subject" select="$subject" />
      <xsl:with-param name="predicate" select="$predicate" />
    </xsl:apply-templates>

  </xsl:template>

  <xsl:template match="*[not(*)][text()]" mode="property">
    <xsl:param name="subject" />

    <xsl:variable name="predicate">
      <xsl:call-template name="check-li" />
    </xsl:variable>

    <xsl:call-template name="output-literal-statement">
      <xsl:with-param name="subject" select="$subject" />
      <xsl:with-param name="predicate" select="$predicate" />
      <xsl:with-param name="object" select="." />
    </xsl:call-template>

  </xsl:template>

  <xsl:template match="*[not(node())]" mode="property">
    <xsl:param name="subject" />

    <xsl:variable name="predicate">
      <xsl:call-template name="check-li" />
    </xsl:variable>

    <xsl:choose>

      <xsl:when test="not(@*) or (@rdf:ID and count(@*) = 1)">
        <xsl:call-template name="output-literal-statement">
          <xsl:with-param name="subject" select="$subject" />
          <xsl:with-param name="predicate" select="$predicate" />
          <xsl:with-param name="object" select="''" />
        </xsl:call-template>
      </xsl:when>

      <xsl:when test="@rdf:resource and count(@*) = 1">
        <xsl:call-template name="output-statement">
          <xsl:with-param name="subject" select="$subject" />
          <xsl:with-param name="predicate" select="$predicate" />
          <xsl:with-param name="object" select="@rdf:resource" />
        </xsl:call-template>
      </xsl:when>

      <xsl:otherwise>
        <xsl:variable name="id">
          <xsl:choose>
            <xsl:when test="@rdf:resource">
              <xsl:value-of select="@rdf:resource" />
            </xsl:when>
            <xsl:when test="@rdf:ID">
              <xsl:value-of select="concat($base-uri, '#', @rdf:ID)" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat('_:', generate-id())" />
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="property-attributes">
          <xsl:apply-templates select="@*" mode="property">
            <xsl:with-param name="subject" select="$id" />
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:if test="$property-attributes">
          <xsl:call-template name="output-statement">
            <xsl:with-param name="subject" select="$subject" />
            <xsl:with-param name="predicate" select="$predicate" />
            <xsl:with-param name="object" select="$id" />
          </xsl:call-template>
          <xsl:copy-of select="$property-attributes" />
        </xsl:if>
      </xsl:otherwise>

    </xsl:choose>

  </xsl:template>

  <!-- property attributes -->

  <xsl:template match="@rdf:RDF" mode="property" />
  <xsl:template match="@rdf:Description" mode="property" />
  <xsl:template match="@rdf:ID" mode="property" />
  <xsl:template match="@rdf:about" mode="property" />
  <xsl:template match="@rdf:bagID" mode="property" />
  <xsl:template match="@rdf:parseType" mode="property" />
  <xsl:template match="@rdf:resource" mode="property" />
  <xsl:template match="@rdf:li" mode="property" />

  <xsl:template match="@rdf:type" mode="property">
    <xsl:param name="subject" />

    <xsl:call-template name="output-type-statement">
      <xsl:with-param name="subject" select="$subject" />
      <xsl:with-param name="object" select="." />
    </xsl:call-template>

  </xsl:template>

  <xsl:template match="@*" mode="property">
    <xsl:param name="subject" />

    <xsl:call-template name="output-literal-statement">
      <xsl:with-param name="subject" select="$subject" />
      <xsl:with-param name="predicate" select="concat(namespace-uri(), local-name())" />
      <xsl:with-param name="object" select="." />
    </xsl:call-template>

  </xsl:template>

  <!-- helper templates -->

  <xsl:template name="check-li">

    <xsl:variable name="id" select="concat(namespace-uri(), local-name())" />

    <xsl:choose>
      <xsl:when test="$id = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#li'">
        <xsl:value-of select="concat('http://www.w3.org/1999/02/22-rdf-syntax-ns#_', 1 + count(preceding-sibling::rdf:li))" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$id" />
      </xsl:otherwise>
    </xsl:choose>

  </xsl:template>

  <xsl:template name="output-type-statement">
    <xsl:param name="subject" />
    <xsl:param name="object" />

    <xsl:call-template name="output-statement">
      <xsl:with-param name="subject" select="$subject" />
      <xsl:with-param name="predicate" select="'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'" />
      <xsl:with-param name="object" select="$object" />
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="output-statement">
    <xsl:param name="subject" />
    <xsl:param name="predicate" />
    <xsl:param name="object" />

    <xsl:if test="not(starts-with($subject, '_:'))">
      <xsl:text>&lt;</xsl:text>
    </xsl:if>

    <xsl:value-of select="$subject" />

    <xsl:if test="not(starts-with($subject, '_:'))">
      <xsl:text>&gt;</xsl:text>
    </xsl:if>

    <xsl:text> &lt;</xsl:text>
    <xsl:value-of select="$predicate" />
    <xsl:text>&gt; </xsl:text>

    <xsl:if test="not(starts-with($object, '_:'))">
      <xsl:text>&lt;</xsl:text>
    </xsl:if>

    <xsl:value-of select="$object" />

    <xsl:if test="not(starts-with($object, '_:'))">
      <xsl:text>&gt;</xsl:text>
    </xsl:if>

    <xsl:text> .&#10;</xsl:text>

  </xsl:template>

  <xsl:template name="output-literal-statement">
    <xsl:param name="subject" />
    <xsl:param name="predicate" />
    <xsl:param name="object" />

    <xsl:if test="not(starts-with($subject, '_:'))">
      <xsl:text>&lt;</xsl:text>
    </xsl:if>

    <xsl:value-of select="$subject" />

    <xsl:if test="not(starts-with($subject, '_:'))">
      <xsl:text>&gt;</xsl:text>
    </xsl:if>

    <xsl:text> &lt;</xsl:text>
    <xsl:value-of select="$predicate" />
    <xsl:text>&gt; "</xsl:text>
    <xsl:value-of select="$object" />
    <xsl:text>" .&#10;</xsl:text>

  </xsl:template>

</xsl:transform>
