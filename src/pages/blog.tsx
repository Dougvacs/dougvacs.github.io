import * as React from 'react'
import Layout from "../components/layout"
import { graphql, Link } from "gatsby"
import {
    postLinkText, heading1, container
} from '../components/layout.module.scss'

const Blog = ({ data }) => {
    const { posts } = data.blog
    return (
        <Layout pageTitle="Blog" subtitleText="Don't expect me to post anything ever. 
        I might delete this site in a month.">
        {posts.map(post => (
            <Link to={post.fields.slug} className={postLinkText}>
                <div style={{"display":"block"}}>
                  <div className={container}>
                    <h1>{post.frontmatter.title}</h1>
                    {post.frontmatter.author}, {post.frontmatter.date}<br></br>
                    {post.excerpt}
                  </div>
                </div>
            </Link>
        ))}
        </Layout>
    )
}

export default Blog

export const pageQuery = graphql`
  query MyQuery {
    blog: allMarkdownRemark {
      posts: nodes {
        frontmatter {
          date(formatString: "DD-MM-YYYY")
          title
          author
        }
        fields {
            slug
        }
        excerpt
        id
      }
    }
  }
`