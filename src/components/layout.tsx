import * as React from 'react'
import { Link } from 'gatsby'
import {
    container, heading, subheading, navLinks, 
    navLinkItem, navLinkText, mainContent, navLinkActive
} from './layout.module.scss'
import e from 'cors'
import { escape } from 'lodash'

const Layout = ({ pageContext, pageTitle, subtitleText, children }) => {
    // Handle case of blog posts not having pageTitle passed to them
    let final_title
    try {
        const postTitle = pageContext.postTitle
        final_title = postTitle
    } catch (err) {
        final_title = pageTitle
    }
    // Handle blog posts having their subtitle being passed as frontmatter
    let final_subtitle
    try {
        const postSubtitle = pageContext.postSubtitle
        final_subtitle = postSubtitle
    } catch (err) {
        final_subtitle = subtitleText
    }
    // Handle blog posts having content separate from "children"
    let final_content
    try {
        const postHTML = pageContext.postHTML
        final_content = <div dangerouslySetInnerHTML={{
            __html: postHTML
        }}></div>
    } catch (err) {
        final_content = children
    }
    
    return (
        <div className={container}>
            <style>
            @import url('https://fonts.googleapis.com/css2?family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&display=swap');
            </style>
            <title>{pageTitle}</title>
            <nav>
                <ul className={navLinks}>
                    <li className={navLinkItem}>
                        <Link to="/" className={navLinkText} activeClassName={navLinkActive}>
                            Home
                        </Link>
                    </li>
                    <li className={navLinkItem}>
                        <Link to="/about" className={navLinkText} activeClassName={navLinkActive}>
                            About
                        </Link>
                    </li>
                    <li className={navLinkItem}>
                        <Link to="/blog" className={navLinkText} activeClassName={navLinkActive}>
                            Blog
                        </Link>
                    </li>
                </ul>
            </nav>
            <main>
                <h1 className={heading}>{final_title}</h1>
                <i className={subheading}>{final_subtitle}</i>
                <hr />
                <div className={mainContent}>
                    {final_content}
                </div>
            </main>
        </div>
    )
}

export default Layout